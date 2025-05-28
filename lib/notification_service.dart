import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;

  // 初始化通知（背景 handler 註冊需放 main.dart）
  static Future<void> init() async {
    await _messaging.requestPermission();

    // 前景通知監聽
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? '';
      final body = message.notification?.body ?? '';
      print('📥 前景通知: $title - $body');
    });

    // 點擊通知後開啟 App 時觸發
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📲 使用者點擊通知: ${message.data}');
    });
  }

  // 訂閱主題
  static Future<void> subscribeToNotifications() async {
    await _messaging.subscribeToTopic('general');
    print('✅ 已訂閱 general 通知');
  }

  // 取消訂閱主題
  static Future<void> unsubscribeFromNotifications() async {
    await _messaging.unsubscribeFromTopic('general');
    print('🚫 已取消訂閱 general 通知');
  }
}
