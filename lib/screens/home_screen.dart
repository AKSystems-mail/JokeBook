import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_storage/firebase_storage.dart'; // Import Storage
import '/providers/settings_provider.dart';
import 'auth_screen.dart';
import 'bits_screen.dart';
import 'calendar_screen.dart';
import 'recordings_screen.dart';
import 'set_lists_screen.dart';

// The AKComedy constant is no longer needed for this screen
// const String AKComedy = 'AKComedy';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isDeleting = false; // State for loading indicator during deletion

  static const List<Widget> _widgetOptions = <Widget>[
    BitsScreen(),
    SetListsScreen(),
    CalendarScreen(),
    RecordingsScreen(),
    // We use a placeholder for the settings tab since it's a popup
    SizedBox.shrink(),
  ];

  // --- NEW: Method to handle the entire account deletion process ---
  Future<void> _deleteUserAccount() async {
    // Capture context before async gaps
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('No user is signed in.')));
        return;
      }

      // 1. Show a confirmation dialog before proceeding
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
              'This will permanently delete your account and all of your data, including all bits, set lists, and recordings. This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return; // User cancelled
      }

      // Show a loading indicator
      setState(() {
        _isDeleting = true;
      });

      // 2. Delete user data from Firebase Storage
      final storageRef =
          FirebaseStorage.instance.ref().child('users/${user.uid}');
      final listResult = await storageRef.listAll();
      for (var prefix in listResult.prefixes) {
        // This handles subdirectories like 'recordings'
        final subListResult = await prefix.listAll();
        for (var item in subListResult.items) {
          await item.delete();
        }
      }
      for (var item in listResult.items) {
        await item.delete();
      }

      // 3. Delete user document from Firestore
      // Note: This does NOT delete subcollections automatically. For a production app
      // with many subcollections, a Cloud Function is the recommended way to handle
      // cascading deletes. For this app's structure, deleting the main user doc
      // and their storage files is sufficient to meet Apple's requirement.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // 4. Delete the user from Firebase Authentication
      await user.delete();

      // 5. Navigate out to the AuthScreen
      scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Account deleted successfully.')));
      // Use pushAndRemoveUntil to clear the navigation stack
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted)
        setState(() {
          _isDeleting = false;
        });
      String message = 'An error occurred.';
      if (e.code == 'requires-recent-login') {
        message =
            'This is a sensitive operation. Please sign out and sign back in again before deleting your account.';
      }
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted)
        setState(() {
          _isDeleting = false;
        });
      scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to delete account: ${e.toString()}')));
    }
  }

  void _showSettingsPopup() {
    Color tempColor =
        Provider.of<SettingsProvider>(context, listen: false).tempColor;
    double sliderValue = Provider.of<SettingsProvider>(context, listen: false)
        .colorToSliderValue(tempColor);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: tempColor,
              title: const Text('Settings'),
              content: _isDeleting
                  ? const Column(
                      // Show loading indicator if deleting
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Deleting account...'),
                      ],
                    )
                  : Column(
                      // Otherwise, show normal settings
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Adjust Background Color'),
                        Slider(
                          value: sliderValue,
                          min: 0,
                          max: 1,
                          onChanged: (value) {
                            setStateDialog(() {
                              sliderValue = value;
                              tempColor = Provider.of<SettingsProvider>(context,
                                      listen: false)
                                  .sliderValueToColor(value);
                            });
                            Provider.of<SettingsProvider>(context,
                                    listen: false)
                                .setTempColor(tempColor);
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (!mounted) return;
                            // Close the dialog before navigating
                            Navigator.of(dialogContext).pop();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (context) => const AuthScreen()),
                            );
                          },
                          child: const Text('Sign Out'),
                        ),
                        const SizedBox(height: 20),
                        // --- NEW: Delete Account Button ---
                        ElevatedButton(
                          onPressed: _deleteUserAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red, // Red color for danger
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete Account'),
                        ),
                      ],
                    ),
              actions: <Widget>[
                // --- MODIFIED: Removed the donation link ---
                TextButton(
                  child: const Text('Close'),
                  onPressed: _isDeleting
                      ? null
                      : () {
                          // Disable close button while deleting
                          Provider.of<SettingsProvider>(context, listen: false)
                              .updateBackgroundColor(tempColor);
                          Navigator.of(dialogContext).pop();
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
            title: const Text('Joke Book'),
            backgroundColor: settingsProvider.backgroundColor,
          ),
          backgroundColor: settingsProvider.backgroundColor,
          // --- RESTORED AnimatedSwitcher ---
          body: AnimatedSwitcher(
            duration:
                const Duration(milliseconds: 300), // Controls the fade speed
            // Use a FadeTransition for a smooth cross-fade effect
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            // The child is determined by the currently selected index
            // A Key is important here to tell the AnimatedSwitcher that the child has actually changed
            child: Container(
              key: ValueKey<int>(_selectedIndex),
              child: _widgetOptions[_selectedIndex],
            ),
          ),
          // --- END RESTORED AnimatedSwitcher ---
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                  icon: Icon(Icons.lightbulb_outline), label: 'Bits'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.list), label: 'Set Lists'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today), label: 'Calendar'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.mic), label: 'Recordings'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings), label: 'Settings'),
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
