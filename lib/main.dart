import 'package:flutter/material.dart';
import 'package:myapp/animation.dart';
import 'package:myapp/signup.dart';
import 'package:myapp/login.dart';
import 'package:myapp/homepage.dart';

void main() {
  // WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();
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
        // '/': (context) => const AnimationPage(),  // 初始
        '/login': (context) => const Login(),
        '/signup': (context) => const Signup(),
        '/': (context) => const HomePage(), // 🔧 修正這裡
      },
    );
  }
}
