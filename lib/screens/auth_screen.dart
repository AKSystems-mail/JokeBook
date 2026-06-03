// lib/screens/auth_screen.dart

import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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


  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address first.')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      await _auth.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      
      if (mounted) {
        showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password Reset'),
          content: const Text(
              "Email sent. If you can’t find it, check the spam folder. It’s the digital equivalent of looking under the couch cushions."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
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


  // --- This is the Apple Sign-In method ---
  Future<void> _signInWithApple() async {
    setState(() { _isLoading = true; });
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final OAuthProvider provider = OAuthProvider('apple.com');
      final OAuthCredential credential = provider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
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
          SnackBar(content: Text('Error logging in with Apple: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.-_';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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
                      TextButton(
                        onPressed: _resetPassword,
                        child: const Text('Forgot Password?'),
                      ),
                      const SizedBox(height: 10),
                      // --- Social Sign-In Row ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // --- Google Sign-In Button ---
                          ElevatedButton(
                            onPressed: _signInWithGoogle,
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(15),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                            child: const FaIcon(FontAwesomeIcons.google, size: 24),
                          ),
                          const SizedBox(width: 20),
                          // --- Apple Sign-In Button ---
                          ElevatedButton(
                            onPressed: _signInWithApple,
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(15),
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                            child: const FaIcon(FontAwesomeIcons.apple, size: 24),
                          ),
                        ],
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