import 'package:flutter/material.dart';
import 'dart:async';
class AnimationPage extends StatefulWidget {
  const AnimationPage({super.key});

  @override
  _AnimationPageState createState() => _AnimationPageState();
}

class _AnimationPageState extends State<AnimationPage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoAnimation;

  late AnimationController _buttonController;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _logoAnimation = Tween<double>(begin: 0, end: 1).animate(_logoController);

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _buttonAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_buttonController);

    _logoController.forward();

    Timer(const Duration(seconds: 3), (){
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFA44F), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _logoAnimation,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 500,
                  height: 500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
