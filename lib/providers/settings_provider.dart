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

  double colorToSliderValue(Color color) {
    const Color startColor = Color(0xFFFFFFFF); // White
    const Color endColor = Color(0xFFF4E204); // Yellow

    int startR = startColor.red;
    int startG = startColor.green;
    int startB = startColor.blue;

    int endR = endColor.red;
    int endG = endColor.green;
    int endB = endColor.blue;

    int currentR = color.red;
    int currentG = color.green;
    int currentB = color.blue;

    double rPos = (currentR - startR) / (endR - startR).toDouble();
    double gPos = (currentG - startG) / (endG - startG).toDouble();
    double bPos = (currentB - startB) / (endB - startB).toDouble();

    return (rPos + gPos + bPos) / 3;
  }

  Color sliderValueToColor(double value) {
    const Color startColor = Color(0xFFFFFFFF); // White
    const Color endColor = Color(0xFFF4E204); // Yellow

    value = value.clamp(0.0, 1.0);

    int startR = startColor.red;
    int startG = startColor.green;
    int startB = startColor.blue;

    int endR = endColor.red;
    int endG = endColor.green;
    int endB = endColor.blue;

    int r = (startR + (endR - startR) * value).round();
    int g = (startG + (endG - startG) * value).round();
    int b = (startB + (endB - startB) * value).round();

    return Color.fromARGB(255, r, g, b);
  }
}
