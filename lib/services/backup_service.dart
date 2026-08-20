import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../models/daily_record.dart';
import '../providers/user_settings_provider.dart';
import 'database_service.dart';

class BackupService {
  static final BackupService instance = BackupService._init();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  BackupService._init();

  Future<bool> isSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } on Object {
      return false;
    }
  }

  Future<void> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('登入已取消');
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<DateTime> backup(UserSettingsProvider settings) async {
    GoogleAuthClient? client;
    try {
      final account =
          await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account == null) throw Exception('未登入 Google 帳號');

      client = await _clientFor(account);
      final driveApi = drive.DriveApi(client);
      final records = await DatabaseService.instance.getAllDailyRecords();
      final backupDate = DateTime.now();
      final backupData = <String, dynamic>{
        'records': records.map((record) => record.toJson()).toList(),
        'settings': settings.toJson(),
        'backup_date': backupDate.toIso8601String(),
        'version': 2,
      };
      final content = utf8.encode(jsonEncode(backupData));
      final file = drive.File()
        ..name = 'period_tracker_backup_${backupDate.toIso8601String()}.json'
        ..mimeType = 'application/json'
        ..parents = <String>['appDataFolder'];

      await driveApi.files.create(
        file,
        uploadMedia: drive.Media(Stream.value(content), content.length),
      );
      return backupDate;
    } on Object catch (error) {
      throw Exception('備份失敗：$error');
    } finally {
      client?.close();
    }
  }

  Future<DateTime?> restore(UserSettingsProvider settings) async {
    GoogleAuthClient? client;
    try {
      final account =
          await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account == null) throw Exception('未登入 Google 帳號');

      client = await _clientFor(account);
      final driveApi = drive.DriveApi(client);
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        orderBy: 'modifiedTime desc',
        pageSize: 1,
        q: "name contains 'period_tracker_backup' and mimeType='application/json'",
        $fields: 'files(id,name,modifiedTime)',
      );
      if (fileList.files?.isEmpty ?? true) throw Exception('找不到備份檔案');

      final file = fileList.files!.first;
      final media = await driveApi.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      final parsed = _parseBackup(bytes);
      final previousRecords =
          await DatabaseService.instance.getAllDailyRecords();
      final previousSettings = settings.toJson();

      try {
        await DatabaseService.instance.replaceAllRecords(parsed.records);
        await settings.fromJson(parsed.settings);
      } on Object {
        await DatabaseService.instance.replaceAllRecords(previousRecords);
        await settings.fromJson(previousSettings);
        rethrow;
      }
      return parsed.backupDate ?? file.modifiedTime;
    } on Object catch (error) {
      throw Exception('還原失敗：$error');
    } finally {
      client?.close();
    }
  }

  _ParsedBackup _parseBackup(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const FormatException('備份不是有效的 JSON 物件');
    final data = Map<String, dynamic>.from(decoded);
    final rawRecords = data['records'];
    final rawSettings = data['settings'];
    if (rawRecords is! List || rawSettings is! Map) {
      throw const FormatException('備份缺少記錄或設定');
    }

    final records = rawRecords
        .map(
          (value) => DailyRecord.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
    final settings = Map<String, dynamic>.from(rawSettings);
    _validateSettings(settings);
    final backupDate = DateTime.tryParse(data['backup_date']?.toString() ?? '');
    return _ParsedBackup(
      records: records,
      settings: settings,
      backupDate: backupDate,
    );
  }

  void _validateSettings(Map<String, dynamic> settings) {
    final cycleLength = settings['cycleLength'];
    final periodLength = settings['periodLength'];
    final enabled = settings['notificationsEnabled'];
    final time = settings['reminderTime'];
    final days = settings['reminderDays'];
    if (cycleLength is! int ||
        cycleLength < 21 ||
        cycleLength > 35 ||
        periodLength is! int ||
        periodLength < 1 ||
        periodLength > 10 ||
        enabled is! bool ||
        time is! String ||
        !RegExp(r'^(?:[01]?\d|2[0-3]):[0-5]?\d$').hasMatch(time) ||
        days is! List ||
        !days.every(
          (value) => value is int && const <int>{0, 1, 3, 7}.contains(value),
        )) {
      throw const FormatException('備份中的設定格式不正確');
    }
  }

  Future<GoogleAuthClient> _clientFor(GoogleSignInAccount account) async {
    final authentication = await account.authentication;
    final accessToken = authentication.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('無法取得 Google 存取權杖');
    }
    return GoogleAuthClient(accessToken);
  }
}

class _ParsedBackup {
  const _ParsedBackup({
    required this.records,
    required this.settings,
    required this.backupDate,
  });

  final List<DailyRecord> records;
  final Map<String, dynamic> settings;
  final DateTime? backupDate;
}

class GoogleAuthClient extends http.BaseClient {
  GoogleAuthClient(String accessToken)
      : _headers = <String, String>{'Authorization': 'Bearer $accessToken'};

  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() => _client.close();
}
