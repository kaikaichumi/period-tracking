import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../models/daily_record.dart';
import '../providers/user_settings_provider.dart';
import '../utils/constants.dart';
import 'database_service.dart';

/// A backup error whose message can be shown to the user as is.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A backup file in the app's private Google Drive folder.
class BackupInfo {
  const BackupInfo({required this.id, this.createdAt, this.recordCount});

  final String id;
  final DateTime? createdAt;

  /// Null for backups made before the count was stored with the file.
  final int? recordCount;
}

class BackupService {
  static final BackupService instance = BackupService._init();

  static const String _recordCountProperty = 'recordCount';

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
    if (account == null) throw const BackupException('登入已取消');
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<DateTime> backup(UserSettingsProvider settings) async {
    GoogleAuthClient? client;
    try {
      final records = await DatabaseService.instance.getAllDailyRecords();
      // An empty backup would become the newest one and hide the real data,
      // e.g. when backing up on a new phone before restoring.
      if (records.isEmpty) {
        throw const BackupException('目前沒有任何記錄，不需要建立備份');
      }

      client = await _clientFor(await _account());
      final driveApi = drive.DriveApi(client);
      final backupDate = DateTime.now();
      final backupData = <String, dynamic>{
        'records': records.map((record) => record.toJson()).toList(),
        'settings': settings.toJson(),
        'backup_date': backupDate.toIso8601String(),
        // 3: records use enum names and symptom IDs (see DailyRecord.toJson).
        'version': 3,
      };
      final content = utf8.encode(jsonEncode(backupData));
      final file = drive.File()
        ..name = 'period_tracker_backup_${backupDate.toIso8601String()}.json'
        ..mimeType = 'application/json'
        ..parents = <String>['appDataFolder']
        ..appProperties = <String, String?>{
          _recordCountProperty: '${records.length}',
        };

      await driveApi.files.create(
        file,
        uploadMedia: drive.Media(Stream.value(content), content.length),
      );
      return backupDate;
    } on Object catch (error) {
      throw BackupException('備份失敗：${_describe(error)}');
    } finally {
      client?.close();
    }
  }

  /// Lists the most recent backups, newest first.
  Future<List<BackupInfo>> listBackups() async {
    GoogleAuthClient? client;
    try {
      client = await _clientFor(await _account());
      final driveApi = drive.DriveApi(client);
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        orderBy: 'modifiedTime desc',
        pageSize: 30,
        q: "name contains 'period_tracker_backup' and mimeType='application/json'",
        $fields: 'files(id,name,modifiedTime,appProperties)',
      );
      return <BackupInfo>[
        for (final file in fileList.files ?? const <drive.File>[])
          if (file.id != null)
            BackupInfo(
              id: file.id!,
              createdAt: file.modifiedTime?.toLocal(),
              recordCount: int.tryParse(
                file.appProperties?[_recordCountProperty] ?? '',
              ),
            ),
      ];
    } on Object catch (error) {
      throw BackupException('讀取備份清單失敗：${_describe(error)}');
    } finally {
      client?.close();
    }
  }

  Future<DateTime?> restore(
    UserSettingsProvider settings,
    BackupInfo backup,
  ) async {
    GoogleAuthClient? client;
    try {
      client = await _clientFor(await _account());
      final driveApi = drive.DriveApi(client);
      final media = await driveApi.files.get(
        backup.id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      final parsed = parseBackup(bytes);
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
      return parsed.backupDate ?? backup.createdAt;
    } on Object catch (error) {
      throw BackupException('還原失敗：${_describe(error)}');
    } finally {
      client?.close();
    }
  }

  /// Validates a downloaded backup before anything on the device is replaced.
  @visibleForTesting
  static ParsedBackup parseBackup(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const FormatException('備份不是有效的 JSON 物件');
    final data = Map<String, dynamic>.from(decoded);
    final rawRecords = data['records'];
    final rawSettings = data['settings'];
    if (rawRecords is! List || rawSettings is! Map) {
      throw const FormatException('備份缺少記錄或設定');
    }
    if (rawRecords.isEmpty) {
      throw const FormatException('這份備份沒有任何記錄');
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
    return ParsedBackup(
      records: records,
      settings: settings,
      backupDate: backupDate,
    );
  }

  static void _validateSettings(Map<String, dynamic> settings) {
    final cycleLength = settings['cycleLength'];
    final periodLength = settings['periodLength'];
    final enabled = settings['notificationsEnabled'];
    final time = settings['reminderTime'];
    final days = settings['reminderDays'];
    if (cycleLength is! int ||
        cycleLength < AppConstants.minCycleLength ||
        cycleLength > AppConstants.maxCycleLength ||
        periodLength is! int ||
        periodLength < AppConstants.minPeriodLength ||
        periodLength > AppConstants.maxPeriodLength ||
        enabled is! bool ||
        time is! String ||
        !RegExp(r'^(?:[01]?\d|2[0-3]):[0-5]?\d$').hasMatch(time) ||
        days is! List ||
        !days.every(
          (value) =>
              value is int && AppConstants.reminderDayOptions.contains(value),
        )) {
      throw const FormatException('備份中的設定格式不正確');
    }
  }

  Future<GoogleSignInAccount> _account() async {
    final account =
        await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    if (account == null) throw const BackupException('未登入 Google 帳號');
    return account;
  }

  Future<GoogleAuthClient> _clientFor(GoogleSignInAccount account) async {
    final authentication = await account.authentication;
    final accessToken = authentication.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const BackupException('無法取得 Google 存取權杖');
    }
    return GoogleAuthClient(accessToken);
  }

  static String _describe(Object error) {
    if (error is BackupException) return error.message;
    if (error is FormatException) return error.message;
    if (error is http.ClientException) return '無法連線到 Google Drive，請確認網路後再試一次';
    if (error is drive.DetailedApiRequestError) {
      return 'Google Drive 回應錯誤（${error.status}）${error.message ?? ''}';
    }
    return '$error'.replaceFirst('Exception: ', '');
  }
}

class ParsedBackup {
  const ParsedBackup({
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
