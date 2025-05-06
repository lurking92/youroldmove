import 'package:flutter/material.dart';
import 'package:myapp/animation.dart';
import 'package:myapp/signup.dart';
import 'package:myapp/login.dart';
import 'package:myapp/homepage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Firebase 測試
  try {
    final snapshot = await FirebaseFirestore.instance.collection('test').get();
    print("✅ Firebase Firestore connected! Documents count: ${snapshot.docs.length}");
  } catch (e) {
    print("❌ Firebase connection error: $e");
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
        '/': (context) => const AnimationPage(),  // 初始
        '/login': (context) => const Login(),
        '/signup': (context) => const Signup(),
        '/home': (context) => const HomePage(), // 🔧 修正這裡
      },
    );
  }
}
