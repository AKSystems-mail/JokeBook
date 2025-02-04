import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);
  
  @override
  AuthScreenState createState() => AuthScreenState();
}

class AuthScreenState extends State<AuthScreen> {
    final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
    bool _isLoading = false;
    

  String _loginMessage = "";

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  
  Future<void> _checkCurrentUser() async {
    setState(() {
    });

    try {
      final user = _auth.currentUser; // Access _auth, not widget.auth
      
        if (user != null) {
          // User is signed in. Navigate only if mounted.
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          // User is not signed in. Set state only if mounted.
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        // Handle any error here. Set state only if mounted.
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        print("Error checking user: $e");
    }
  }

  Future<void> _signInWithEmailPassword() async {
    setState(() {
        _isLoading = true;
    });
    try {
      final email = _emailController.text;
      final password = _passwordController.text;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (!mounted) return;
      setState(() {
          _isLoading = false;
      });
      if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
      };
    } catch (e) {
         setState(() {
          _isLoading = false;
        });
        if (mounted) { // Very important to check mounted here as well
          
          // Handle error (show snackbar, etc.)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error login in: $e')),
          );
        }
      
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JokeBook'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading ? const Center(child: CircularProgressIndicator()) :  Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _signInWithEmailPassword,
                  child: const Text('Sign in with Email/Password'),
              ),
              const SizedBox(height: 18),
              Text(_loginMessage),
            ],
          
          
          
          
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose(); 
  }
}
