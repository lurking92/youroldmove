import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:myapp/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _updatePreference(String uid, String key, bool value) {
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
    return docRef.set({'preferences': {key: value}}, SetOptions(merge: true));
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final uid = user.uid;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading settings'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final userName = data['name'] as String? ?? 'No Name';
          final email = data['email'] as String? ?? user.email ?? '';
          final prefs = data['preferences'] as Map<String, dynamic>? ?? {};
          final notificationsEnabled = prefs['notifications'] as bool? ?? true;

          return Stack(
            children: [
              Container(
                height: 200,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFA44F), Color(0xFFFA709A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 120),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Colors.white,
                              backgroundImage: const AssetImage('assets/images/profile.png'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(userName,
                                      style: const TextStyle(
                                          fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(email, style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Account',
                      children: [
                        _SettingsTile(
                          icon: Icons.person,
                          label: 'Edit Profile',
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                        ),
                        _SettingsTile(
                          icon: Icons.lock,
                          label: 'Change Password',
                          onTap: () => Navigator.pushNamed(context, '/change-password'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Preferences',
                      children: [
                        SwitchListTile(
                          value: notificationsEnabled,
                          onChanged: (val) => _updatePreference(uid, 'notifications', val),
                          title: const Text('Enable Notifications'),
                          secondary: const Icon(Icons.notifications),
                        ),
                        SwitchListTile(
                          value: themeProvider.isDarkMode,
                          onChanged: (val) {
                            themeProvider.toggleTheme(val);
                            _updatePreference(uid, 'darkMode', val);
                          },
                          title: const Text('Dark Mode'),
                          secondary: const Icon(Icons.dark_mode),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Others',
                      children: [
                        _SettingsTile(
                          icon: Icons.info_outline,
                          label: 'About',
                          onTap: () => showAboutDialog(
                            context: context,
                            applicationName: 'Sport Tracker',
                            applicationVersion: '1.0.0',
                            children: const [Text('Developed by Your Team')],
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.logout,
                          label: 'Log Out',
                          iconColor: Colors.redAccent,
                          onTap: () => _logout(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Theme.of(context).iconTheme.color),
      title: Text(label),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
