import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:myapp/animation.dart';
import 'package:myapp/edit_profile.dart';
import 'package:myapp/homepage.dart';
import 'package:myapp/login.dart';
import 'package:myapp/record.dart';
import 'package:myapp/setting.dart';
import 'package:myapp/signup.dart';
// 新增 import
import 'package:myapp/start.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  try {
    final snapshot = await FirebaseFirestore.instance.collection('test').get();
    print("✅ Connected Firestore: docs=${snapshot.docs.length}");
  } catch (e) {
    print("❌ Firestore error: $e");
  }

  runApp(const SportApp());
}

class SportApp extends StatelessWidget {
  const SportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Your Old Move',
      theme: ThemeData(primarySwatch: Colors.pink),
      initialRoute: '/',
      routes: {
        '/': (context) => const AnimationPage(),
        '/login': (context) => const Login(),
        '/signup': (context) => const Signup(),
        '/home': (context) => const HomePage(),
        '/setting': (context) => const SettingsPage(),
        '/profile': (context) => const EditProfilePage(),
        // 新增路由
        '/start': (context) => StartPage(),
        '/record': (context) => RecordPage(),
      },
    );
  }
}
