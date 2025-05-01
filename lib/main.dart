import 'package:flutter/material.dart';
import 'package:myapp/animation.dart';
import 'package:myapp/signup.dart';
import 'package:myapp/login.dart';

void main() {
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
        '/home': (context) => const HomePage(), // 🔧 修正這裡
      },
    );
  }
}

// 🔧 加上 HomePage 定義
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Welcome to Your Old Move')),
    );
  }
}
