// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/bit.dart';
import 'models/set_list.dart';
import 'providers/bit_provider.dart';
import 'providers/set_list_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/recordings_provider.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/recordings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI mode to edge-to-edge for Android 15+ support
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Set system overlay style for edge-to-edge transparency
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();
  Hive.registerAdapter(BitAdapter());
  Hive.registerAdapter(SetListAdapter());

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State createState() => _MyAppState();
}

class _MyAppState extends State {
  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        debugPrint("User is signed in: ${user.uid}");
        // You can trigger navigation or state updates here if needed
      } else {
        debugPrint("User is signed out.");
      }
    }, onError: (error) {
      debugPrint("Auth state listener error: $error");
    });
  }

  Future<bool> _checkAuthenticationStatus() async {
    // Return true if a user is currently signed in, false otherwise
    return FirebaseAuth.instance.currentUser != null;
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
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue)
                  .copyWith(secondary: const Color(0xFFADD8E6)),
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: settingsProvider.backgroundColor, // Tie scaffold background color to SettingsProvider
              appBarTheme: AppBarTheme(
                backgroundColor: settingsProvider.backgroundColor,
                elevation: 0.0, // Set elevation to 0 to remove initial shadow
                scrolledUnderElevation: 0.0, // Tie AppBar background color to SettingsProvider
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
