import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isLoading = false;

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  void _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser!;
    final email = user.email!;
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    try {
      // Re-authenticate
      final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = 'Password update failed';
      if (e.code == 'wrong-password') {
        message = 'Incorrect current password';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please re-login and try again';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _currentPasswordController,
                decoration: _inputDecoration('Current Password'),
                obscureText: true,
                validator: (value) =>
                value != null && value.isNotEmpty ? null : 'Please enter current password',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                decoration: _inputDecoration('New Password'),
                obscureText: true,
                validator: (value) =>
                value != null && value.length >= 6 ? null : 'Password must be at least 6 characters',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                decoration: _inputDecoration('Confirm New Password'),
                obscureText: true,
                validator: (value) =>
                value == _newPasswordController.text ? null : 'Passwords do not match',
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _changePassword,
                child: const Text('Update Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
