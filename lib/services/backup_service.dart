// lib/services/backup_service.dart
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:period_tracking/models/daily_record.dart';
import 'package:period_tracking/providers/user_settings_provider.dart';
import 'package:period_tracking/services/database_service.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  
  // 只使用需要的最小權限
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  );

  BackupService._init();

  Future<bool> isSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      print('檢查登入狀態時發生錯誤: $e');
      return false;
    }
  }

  Future<void> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) throw Exception('登入已取消');
    } catch (e) {
      throw Exception('Google 登入失敗: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      throw Exception('登出失敗: $e');
    }
  }

  Future<void> backup() async {
    try {
      // 確保已登入
      final account = await _googleSignIn.signInSilently() ?? 
                     await _googleSignIn.signIn();
                     
      if (account == null) throw Exception('未登入 Google 帳號');

      final auth = await account.authentication;
      final client = GoogleAuthClient(auth);
      final driveApi = drive.DriveApi(client);

      // 獲取資料
      final records = await DatabaseService.instance.getAllDailyRecords();
      final settings = await UserSettingsProvider().toJson();
      
      final backupData = {
        'records': records.map((r) => r.toJson()).toList(),
        'settings': settings,
        'backup_date': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      };

      final content = utf8.encode(jsonEncode(backupData));

      // 創建檔案 metadata
      var file = drive.File()
        ..name = 'period_tracker_backup_${DateTime.now().toIso8601String()}.json'
        ..mimeType = 'application/json'
        ..parents = ['appDataFolder']; // 使用 appDataFolder 存放備份

      // 上傳檔案
      await driveApi.files.create(
        file,
        uploadMedia: drive.Media(Stream.fromIterable([content]), content.length),
      );

      client.close();
    } catch (e) {
      throw Exception('備份失敗: $e');
    }
  }

  Future<void> restore() async {
    try {
      // 確保已登入
      final account = await _googleSignIn.signInSilently() ?? 
                     await _googleSignIn.signIn();
                     
      if (account == null) throw Exception('未登入 Google 帳號');

      final auth = await account.authentication;
      final client = GoogleAuthClient(auth);
      final driveApi = drive.DriveApi(client);

      // 搜尋最新的備份
      final fileList = await driveApi.files.list(
        spaces: 'appDataFolder',
        orderBy: 'modifiedTime desc',
        pageSize: 1,
        q: "name contains 'period_tracker_backup' and mimeType='application/json'",
      );

      if (fileList.files?.isEmpty ?? true) {
        throw Exception('未找到備份檔案');
      }

      // 下載檔案
      final file = fileList.files!.first;
      final response = await driveApi.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // 讀取內容
      final List<int> dataStore = [];
      await for (final data in response.stream) {
        dataStore.addAll(data);
      }

      // 解析並還原資料
      final backupData = jsonDecode(utf8.decode(dataStore));

      await DatabaseService.instance.clearAllData();
      for (var recordJson in backupData['records']) {
        await DatabaseService.instance.saveDailyRecord(
          DailyRecord.fromJson(recordJson),
        );
      }

      await UserSettingsProvider().fromJson(backupData['settings']);

      client.close();
    } catch (e) {
      throw Exception('還原失敗: $e');
    }
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(GoogleSignInAuthentication auth)
      : _headers = {'Authorization': 'Bearer ${auth.accessToken}'};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
  }
}