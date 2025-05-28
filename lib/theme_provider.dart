import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode;

  ThemeProvider(this._isDarkMode);

  bool get isDarkMode => _isDarkMode;

  ThemeMode get currentTheme => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme(bool isOn) {
    _isDarkMode = isOn;
    notifyListeners();
  }
}
