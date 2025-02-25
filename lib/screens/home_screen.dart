import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '/providers/settings_provider.dart';
import 'auth_screen.dart';
import 'bits_screen.dart';
import 'calendar_screen.dart';
import 'recordings_screen.dart';
import 'set_lists_screen.dart';

const String AKComedy = 'AKComedy'; // Define your CashApp username as a constant

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
    double sliderValue = Provider.of<SettingsProvider>(context, listen: false).colorToSliderValue(tempColor);

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
                  Slider(
                    value: sliderValue,
                    min: 0,
                    max: 1,
                    onChanged: (value) {
                      setState(() {
                        sliderValue = value;
                        tempColor = Provider.of<SettingsProvider>(context, listen: false).sliderValueToColor(value);
                      });
                      Provider.of<SettingsProvider>(context, listen: false).setTempColor(tempColor);
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Use the constant in your URL string
                        final Uri cashAppUri = Uri.parse('https://cash.app/$AKComedy');
                        launchUrl(cashAppUri);
                      },
                      child: const Text(
                        'Buy me a bagel...',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    TextButton(
                      child: const Text('Close'),
                      onPressed: () {
                        Provider.of<SettingsProvider>(context, listen: false)
                            .updateBackgroundColor(tempColor);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
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
                setState(() {
                  _selectedIndex = index;
                });
              }
            },
          ),
        );
      },
    );
  }
}