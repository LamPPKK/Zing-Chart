import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'zing_chart_screen.dart'; // Assuming this is where you want to navigate after login
import 'home_screen.dart';

  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signInWithEmailAndPassword,
              child: const Text('Login'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _registerWithEmailAndPassword,
              child: const Text('Register'),
            ),
            TextButton(
              onPressed: () {}, child: const Text('Continue as Guest'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signInWithEmailAndPassword() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // If successful, navigate to the next screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      // If login fails, show an error message using FlutterToast
      _showToast(e.message ?? 'An error occurred during login.');
    }
  }

  Future<void> _registerWithEmailAndPassword() async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // If successful, navigate to the next screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      // If registration fails, show an error message using FlutterToast
      _showToast(e.message ?? 'An error occurred during registration.');
    }
  }

  Future<void> _signInAnonymously() async {
    final userCredential = await FirebaseAuth.instance.signInAnonymously();
    print("Signed in with temporary account ${userCredential.user?.uid}");
  }

  void _showToast(String message) {
    FlutterToast fToast = FlutterToast();
    fToast.init(context);
    fToast.showToast(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25.0),
          color: Colors.redAccent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error),
            const SizedBox(
              width: 12.0,
            ),
            Text(message),
          ],
        ),
      ),
      gravity: ToastGravity.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }
}