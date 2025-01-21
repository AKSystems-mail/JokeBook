import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:jokebook/providers/settings_provider.dart';

import 'auth_screen.dart';
import 'bits_screen.dart';
import 'calendar_screen.dart';
import 'recordings_screen.dart';
import 'set_lists_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    BitsScreen(),
    SetListsScreen(),
    CalendarScreen(),
    RecordingsScreen(),
  ];

  void _showSettingsPopup() {
    Color tempColor = Provider.of<SettingsProvider>(context, listen: false).tempColor;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: tempColor,
              title: const Text('Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Adjust Background Color'),
                  ColorSlider(
                    color: tempColor,
                    onColorChanged: (Color newColor) {
                      setState(() {
                        tempColor = newColor;
                      });
                      Provider.of<SettingsProvider>(context, listen: false).setTempColor(newColor);
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const AuthScreen()),
                      );
                    },
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Close'),
                  onPressed: () {
                    Provider.of<SettingsProvider>(context, listen: false).updateBackgroundColor(tempColor);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Container(
              color: settingsProvider.backgroundColor,
              padding: const EdgeInsets.all(8.0),
              child: const Text('Joke Book'),
            ),
            backgroundColor: settingsProvider.backgroundColor,
          ),
          backgroundColor: settingsProvider.backgroundColor,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: _widgetOptions[_selectedIndex],
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.lightbulb_outline),
                label: 'Bits',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list),
                label: 'Set Lists',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today),
                label: 'Calendar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.mic),
                label: 'Recordings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.amber[800],
            unselectedItemColor: Colors.grey,
            backgroundColor: settingsProvider.backgroundColor,
            onTap: (int index) {
              if (index == 4) {
                _showSettingsPopup();
              } else {
                setState(() { _selectedIndex = index; });
              }
            },
          ),
        );
      },
    );
  }
}

// Custom ColorSlider Widget (in home_screen.dart)
class ColorSlider extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const ColorSlider({super.key, required this.color, required this.onColorChanged});

  @override
  State<ColorSlider> createState() => _ColorSliderState();
}

class _ColorSliderState extends State<ColorSlider> {
  late double _sliderValue;

  @override
  void initState() {
    super.initState();
    _sliderValue = _colorToSliderValue(widget.color);
  }

  double _colorToSliderValue(Color color) {
    const Color startColor = Color(0xFFFFFFFF); // White
    const Color endColor = Color(0xFFF4E204);   // Yellow

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

  Color _sliderValueToColor(double value) {
    const Color startColor = Color(0xFFFFFFFF); // White
    const Color endColor = Color(0xFFF4E204);   // Yellow

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

  @override
  void didUpdateWidget(covariant ColorSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _sliderValue = _colorToSliderValue(widget.color);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: _sliderValue,
      min: 0,
      max: 1,
      onChanged: (value) {
        setState(() {
          _sliderValue = value;
        });
        widget.onColorChanged(_sliderValueToColor(value));
      },
    );
  }
}