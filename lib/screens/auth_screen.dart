// lib/screens/auth_screen.dart

import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '/providers/settings_provider.dart';

final _log = Logger('AuthScreen');

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    // This function remains the same
    setState(() { _isLoading = true; });
    try {
      final user = _auth.currentUser;
      if (user != null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        if (mounted) setState(() { _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; });
      _log.info("Error checking user: $e");
    }
  }


  Future<void> _signInOrSignUpWithEmailPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    // --- FIX: Define email and password outside the try block ---
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    // ---------------------------------------------------------

    try {
      // Step 1: Try to sign in
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // If sign-in is successful, navigate to home
      if (mounted) Navigator.pushReplacementNamed(context, '/home');

    } on FirebaseAuthException catch (e) {
      // Step 2: If sign-in fails, check the error code
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        // User does not exist, so try to create a new account
        try {
          // --- FIX: Use the already defined email and password variables ---
          final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
          if (userCredential.user != null) {
            await _createUserDocumentIfNotExist(userCredential.user!);
          }
          // If account creation is successful, navigate to home
          if (mounted) Navigator.pushReplacementNamed(context, '/home');
        } on FirebaseAuthException catch (createError) {
          // Handle errors during account creation (e.g., weak-password)
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error creating account: ${createError.message}')),
            );
          }
        }
      } else {
        // Handle other sign-in errors (e.g., wrong-password)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging in: ${e.message}')),
          );
        }
      }
    } catch (e) {
      // Handle any other unexpected errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
        );
      }
    } finally {
      // Ensure loading indicator is always turned off
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }


  // --- This is your personal version with Google Sign-In ---
  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) { // User cancelled the sign-in
        setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _createUserDocumentIfNotExist(user);
      }

      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging in with Google: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }


  Future<void> _createUserDocumentIfNotExist(User user) async {
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      await _db.collection('users').doc(user.uid).set({
        'createdAt': FieldValue.serverTimestamp(),
        'email': user.email,
        'displayName': user.displayName,
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: settingsProvider.backgroundColor,
            title: const Text('JokeBook'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        // --- Use the new combined method ---
                        onPressed: _signInOrSignUpWithEmailPassword,
                        child: const Text('Sign In / Sign Up'),
                      ),
                      const SizedBox(height: 10),
                      // --- This is the Google Sign-In button for your personal version ---
                      ElevatedButton(
                        onPressed: _signInWithGoogle,
                        child: const Text('Sign in with Google'),
                      ),
                      // --- The "Create Account" button is removed ---
                    ],
                  ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}