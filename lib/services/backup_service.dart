// lib/services/backup_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/providers/user_settings_provider.dart';
import 'package:period_tracking/services/database_service.dart';

class BackupService {
  static final BackupService instance = BackupService._init();

  static const List<String> _scopes = <String>[
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  bool _initialized = false;
  GoogleSignInAccount? _currentAccount;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _eventsSub;

  BackupService._init();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize();
    _eventsSub ??=
        GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _currentAccount = event.user;
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        _currentAccount = null;
      }
    });
    _initialized = true;
  }

  Future<bool> isSignedIn() async {
    try {
      await _ensureInitialized();
      if (_currentAccount != null) return true;
      final account =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account != null) {
        _currentAccount = account;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> signIn() async {
    try {
      await _ensureInitialized();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception('此平台不支援 Google 登入');
      }
      _currentAccount =
          await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw Exception('登入已取消');
      }
      throw Exception('Google 登入失敗: ${e.description ?? e.code}');
    } catch (e) {
      throw Exception('Google 登入失敗: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
      _currentAccount = null;
    } catch (e) {
      throw Exception('登出失敗: $e');
    }
  }

  Future<_AuthSession> _getAuthSession() async {
    await _ensureInitialized();
    var account = _currentAccount;
    account ??= await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (account == null) {
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception('未登入 Google 帳號');
      }
      account =
          await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
    }
    _currentAccount = account;

    final authClient = account.authorizationClient;
    var authorization = await authClient.authorizationForScopes(_scopes);
    authorization ??= await authClient.authorizeScopes(_scopes);

    return _AuthSession(GoogleAuthClient(authorization.accessToken));
  }

  Future<void> backup() async {
    final session = await _getAuthSession();
    try {
      final driveApi = drive.DriveApi(session.client);

      final records = await DatabaseService.instance.getAllDailyRecords();
      final settings = await UserSettingsProvider().toJson();

      final backupData = {
        'records': records.map((r) => r.toJson()).toList(),
        'settings': settings,
        'backup_date': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      };

      final content = utf8.encode(jsonEncode(backupData));

      final file = drive.File()
        ..name =
            'period_tracker_backup_${DateTime.now().toIso8601String()}.json'
        ..mimeType = 'application/json'
        ..parents = ['appDataFolder'];

      await driveApi.files.create(
        file,
        uploadMedia:
            drive.Media(Stream.fromIterable([content]), content.length),
      );
    } catch (e) {
      throw Exception('備份失敗: $e');
    } finally {
      session.client.close();
    }
  }

  Future<void> restore() async {
    final session = await _getAuthSession();
    try {
      final driveApi = drive.DriveApi(session.client);

      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        orderBy: 'modifiedTime desc',
        pageSize: 1,
        q: "name contains 'period_tracker_backup' and mimeType='application/json'",
      );

      if (fileList.files?.isEmpty ?? true) {
        throw Exception('未找到備份檔案');
      }

      final file = fileList.files!.first;
      final response = await driveApi.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> dataStore = [];
      await for (final data in response.stream) {
        dataStore.addAll(data);
      }

      final backupData = jsonDecode(utf8.decode(dataStore));

      await DatabaseService.instance.clearAllData();
      for (var recordJson in backupData['records']) {
        await DatabaseService.instance.saveDailyRecord(
          DailyRecord.fromJson(recordJson),
        );
      }

      await UserSettingsProvider().fromJson(backupData['settings']);
    } catch (e) {
      throw Exception('還原失敗: $e');
    } finally {
      session.client.close();
    }
  }
}

class _AuthSession {
  final GoogleAuthClient client;
  _AuthSession(this.client);
}

class GoogleAuthClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}
