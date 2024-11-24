// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  NotificationService._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 初始化時區資料
      tz.initializeTimeZones();
      
      // 使用系統默認時區
      tz.setLocalLocation(tz.getLocation('Asia/Taipei')); 
      
      // Android 設定
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // 初始化設定
      final InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );
      
      // 初始化通知插件
      await _notifications.initialize(
        initSettings,
        onDidReceiveBackgroundNotificationResponse: (details) => onSelectNotification(details.payload),
        onDidReceiveNotificationResponse: (details) => onSelectNotification(details.payload),
      );

      _isInitialized = true;
      debugPrint('通知服務初始化成功');
    } catch (e) {
      debugPrint('通知服務初始化失敗: $e');
      _isInitialized = false;
    }
  }

  Future<void> onSelectNotification(String? payload) async {
    if (payload != null) {
      debugPrint('通知payload: $payload');
    }
  }

  // 確保初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  // 安排經期提醒
  Future<void> schedulePeriodReminders(
    DateTime nextPeriod,
    Set<int> reminderDays,
    TimeOfDay reminderTime,
  ) async {
    try {
      await _ensureInitialized();

      // 先取消所有現有的提醒
      await cancelAll();

      if (reminderDays.isEmpty) {
        debugPrint('沒有需要安排的提醒日期');
        return;
      }

      // 為每個提醒日期設定通知
      for (var days in reminderDays) {
        final scheduledDate = nextPeriod.subtract(Duration(days: days));
        
        // 跳過已經過去的日期
        if (scheduledDate.isBefore(DateTime.now())) {
          debugPrint('跳過過期的提醒日期: $scheduledDate');
          continue;
        }

        try {
          // 設定具體的提醒時間
          final scheduledDateTime = tz.TZDateTime(
            tz.local,
            scheduledDate.year,
            scheduledDate.month,
            scheduledDate.day,
            reminderTime.hour,
            reminderTime.minute,
          );

          final androidDetails = const AndroidNotificationDetails(
            'period_channel',
            '經期提醒',
            channelDescription: '月經週期追蹤提醒',
            importance: Importance.high,
            priority: Priority.high,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
          );

          final platformDetails = NotificationDetails(
            android: androidDetails,
          );

          // 根據不同的提醒日期設定不同的消息
          String message;
          if (days == 0) {
            message = '您的經期預計今天開始';
          } else if (days == 1) {
            message = '您的經期預計明天開始';
          } else if (days == 3) {
            message = '您的經期預計在3天後開始';
          } else {
            message = '您的經期預計在一週後開始';
          }

          await _notifications.zonedSchedule(
            days, // 使用天數作為通知ID
            '經期提醒',
            message,
            scheduledDateTime,
            platformDetails,
            androidAllowWhileIdle: true,
            uiLocalNotificationDateInterpretation: 
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'period_reminder_$days',
          );
          
          debugPrint('成功安排提醒: $days 天前，時間: ${scheduledDateTime.toString()}');
        } catch (e) {
          debugPrint('安排單個提醒失敗: $e');
        }
      }
    } catch (e) {
      debugPrint('安排提醒失敗: $e');
      rethrow;
    }
  }

  // 取消所有通知
  Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
      debugPrint('已取消所有通知');
    } catch (e) {
      debugPrint('取消通知失敗: $e');
      rethrow;
    }
  }

  // 取消特定通知
  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
      debugPrint('已取消通知 ID: $id');
    } catch (e) {
      debugPrint('取消通知失敗: $e');
      rethrow;
    }
  }

  // 檢查通知權限
  Future<bool> checkPermissions() async {
    try {
      // 在 Android 上請求權限
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
              
      if (androidImplementation != null) {
        final granted = await androidImplementation.areNotificationsEnabled();
        return granted ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('檢查通知權限失敗: $e');
      return false;
    }
  }

  // 獲取待處理的通知
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      debugPrint('獲取待處理通知失敗: $e');
      return [];
    }
  }

  // 發送測試通知
  Future<void> showTestNotification() async {
    try {
      await _ensureInitialized();

      final androidDetails = const AndroidNotificationDetails(
        'test_channel',
        '測試通知',
        channelDescription: '用於測試的通知頻道',
        importance: Importance.high,
        priority: Priority.high,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(
        999, // 測試通知使用特定ID
        '測試通知',
        '這是一條測試通知，用於確認通知功能是否正常運作。',
        platformDetails,
      );
      debugPrint('測試通知已發送');
    } catch (e) {
      debugPrint('發送測試通知失敗: $e');
      rethrow;
    }
  }

  // 驗證和重設通知
  Future<void> validateAndRescheduleNotifications(
    DateTime nextPeriod,
    Set<int> reminderDays,
    TimeOfDay reminderTime,
  ) async {
    try {
      await _ensureInitialized();

      // 檢查權限
      if (!await checkPermissions()) {
        debugPrint('通知權限未授予');
        return;
      }

      // 取消所有現有通知
      await cancelAll();

      // 重新安排通知
      await schedulePeriodReminders(nextPeriod, reminderDays, reminderTime);
      
      // 獲取並記錄待處理的通知
      final pendingNotifications = await getPendingNotifications();
      debugPrint('已安排的通知數量: ${pendingNotifications.length}');
      
      for (var notification in pendingNotifications) {
        debugPrint('待處理通知: ID=${notification.id}, '
            'title=${notification.title}, '
            'body=${notification.body}');
      }
    } catch (e) {
      debugPrint('驗證和重設通知失敗: $e');
      rethrow;
    }
  }
}