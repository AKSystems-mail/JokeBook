import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/bit.dart';
import 'models/set_list.dart';
import 'providers/bit_provider.dart';
import 'providers/set_list_provider.dart';
import 'providers/settings_provider.dart'; // Import the SettingsProvider
import 'providers/recordings_provider.dart'; // Import the RecordingsProvider
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/recordings_screen.dart'; // Import the RecordingsScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    // Initialize Firebase before Hive
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter(); // Initialize Hive after Firebase
  Hive.registerAdapter(BitAdapter()); // Register the BitAdapter
  Hive.registerAdapter(SetListAdapter());
  runApp(const MyApp());

  // Listen for authentication state changes
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {}
  }).onError((error, stackTrace) {});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _checkAuthenticationStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BitProvider()),
        ChangeNotifierProvider(create: (_) => SetListProvider()),
        ChangeNotifierProvider(
            create: (_) => RecordingsProvider()), // Add the RecordingsProvider
        ChangeNotifierProvider(
            create: (_) => SettingsProvider()), // Add the SettingsProvider
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: 'Joke Book',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue)
                  .copyWith(secondary: const Color(0xFFADD8E6)),
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: settingsProvider.backgroundColor, // Tie scaffold background color to SettingsProvider
              appBarTheme: AppBarTheme(
                backgroundColor: settingsProvider.backgroundColor, // Tie AppBar background color to SettingsProvider
                titleTextStyle: const TextStyle(
                  fontFamily: 'PermanentMarker',
                  fontSize: 24,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(fontSize: 16), // Adjust as needed
                bodyMedium: TextStyle(fontSize: 14),
                bodySmall: TextStyle(fontSize: 16),
                labelLarge: TextStyle(fontSize: 18),
                // ... Add other text styles with adjusted font sizes as needed
                // e.g., titleLarge, titleMedium, titleSmall, etc.
              ),
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => FutureBuilder<bool>(
                    future: _checkAuthenticationStatus(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        // While waiting for the future to complete, you can display a loading indicator
                        return const Scaffold(
                            body: Center(child: CircularProgressIndicator()));
                      } else {
                        return snapshot.data == true
                            ? const HomeScreen()
                            : const AuthScreen();
                      }
                    },
                  ),
              '/home': (context) => const HomeScreen(),
              '/recordings': (context) =>
                  const RecordingsScreen(), // Add the RecordingsScreen route
            },
          );
        },
      ),
    );
  }
}
