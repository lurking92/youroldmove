import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isLoading = false;

  void _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.currentUser!
          .updatePassword(_passwordController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密碼已成功更新')),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = '更新失敗';
      if (e.code == 'requires-recent-login') {
        message = '請重新登入後再試一次';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更改密碼')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: '新密碼'),
                obscureText: true,
                validator: (value) =>
                value != null && value.length >= 6 ? null : '密碼至少需6個字元',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                decoration: const InputDecoration(labelText: '確認新密碼'),
                obscureText: true,
                validator: (value) =>
                value == _passwordController.text ? null : '密碼不一致',
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _changePassword,
                child: const Text('更新密碼'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
