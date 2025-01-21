import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  Color _backgroundColor = const Color(0xFFFFFFFF);
  Color _tempColor = const Color(0xFFFFFFFF);
  Color _textColor = const Color(0xFF000000); // Default text color is black

  Color get backgroundColor => _backgroundColor;
  Color get tempColor => _tempColor;
  Color get textColor => _textColor;

  SettingsProvider() {
    _loadBackgroundColor();
  }

  Future<void> _loadBackgroundColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('backgroundColor') ?? 0xFFFFFFFF;
    _backgroundColor = Color(colorValue);
    _tempColor = _backgroundColor; // Set tempColor to backgroundColor initially
    notifyListeners();
  }

  void setTempColor(Color color) {
    _tempColor = color;
    notifyListeners();
  }

  Future<void> updateBackgroundColor(Color color) async {
    _backgroundColor = color;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('backgroundColor', color.value);
    notifyListeners();
  }

  void updateTextColor(Color color) {
    _textColor = color;
    notifyListeners();
  }
}