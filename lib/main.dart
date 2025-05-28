import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:myapp/notification_service.dart';

// Pages
import 'package:myapp/theme_provider.dart';
import 'package:myapp/animation.dart';
import 'package:myapp/login.dart';
import 'package:myapp/signup.dart';
import 'package:myapp/homepage.dart';
import 'package:myapp/setting.dart';
import 'package:myapp/edit_profile.dart';
import 'package:myapp/start.dart';
import 'package:myapp/record.dart';
import 'package:myapp/team.dart';
import 'package:myapp/health.dart';
import 'ChangePasswordPage.dart';
import 'package:myapp/notification_service.dart';

// ✅ 背景推播處理函數（需放在最外層）
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔕 背景通知收到: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ 初始化背景推播處理器
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ 初始化通知服務（前景推播）
  await NotificationService.init();

  // ✅ 取得 darkMode 設定
  bool darkMode = false;
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null) {
      final prefs = data['preferences'] as Map<String, dynamic>? ?? {};
      darkMode = prefs['darkMode'] as bool? ?? false;
    }
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(darkMode),
      child: const SportApp(),
    ),
  );
}

class SportApp extends StatelessWidget {
  const SportApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Your Old Move',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.currentTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const AnimationPage(),
        '/login': (context) => const Login(),
        '/signup': (context) => const Signup(),
        '/home': (context) => const HomePage(),
        '/setting': (context) => const SettingsPage(),
        '/profile': (context) => const EditProfilePage(),
        '/start': (context) => StartPage(),
        '/record': (context) => RecordPage(),
        '/team': (context) => const TeamPage(),
        '/health': (context) => const HealthPage(),
        '/change-password': (context) => const ChangePasswordPage(),
      },
    );
  }
}
