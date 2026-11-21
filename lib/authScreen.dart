import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'main.dart' show AuthService;

class AuthScreen extends StatefulWidget {
  final AuthService auth;

  const AuthScreen({super.key, required this.auth});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  bool registering = false;
  bool busy = false;
  String error = '';

  Future<void> submit() async {
    if (busy) return;

    final emailText = email.text.trim();
    final passwordText = password.text;

    if (emailText.isEmpty ||
        passwordText.isEmpty ||
        (registering &&
            (firstName.text.trim().isEmpty || lastName.text.trim().isEmpty))) {
      setState(() {
        error = 'fill in all the feilds';
      });
      return;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(emailText)) {
      setState(() {
        error = 'enter a valid email';
      });
      return;
    }

    if (registering && passwordText.length < 6) {
      setState(() {
        error = 'password needs atleast 6 characters';
      });
      return;
    }

    setState(() {
      busy = true;
      error = '';
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      if (registering) {
        await widget.auth.register(
          emailText,
          passwordText,
          firstName: firstName.text.trim(),
          lastName: lastName.text.trim(),
        );
      } else {
        await widget.auth.signIn(emailText, passwordText);
      }
    } on FirebaseAuthException catch (e) {
      String message = registering
          ? 'couldnt register:'
          : 'email or password is wrong';

      if (e.code == 'email-already-in-use') {
        message = 'email already registred';
      } else if (e.code == 'weak-password') {
        message = 'use a stronger password';
      } else if (e.code == 'network-request-failed') {
        message = 'no internet connection';
      } else if (e.code == 'too-many-requests') {
        message = 'too many tries, try again later';
      }

      if (mounted) {
        setState(() {
          error = message;
        });
      }
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('couldnt save your user info')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(registering ? 'register' : 'sign in')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (registering)
              TextField(
                controller: firstName,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'first name'),
              ),
            if (registering)
              TextField(
                controller: lastName,
                enabled: !busy,
                decoration: const InputDecoration(labelText: 'last name'),
              ),
            TextField(
              controller: email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'email'),
            ),
            TextField(
              controller: password,
              enabled: !busy,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'password'),
            ),
            const SizedBox(height: 16),
            if (error.isNotEmpty) Text(error),
            ElevatedButton(
              onPressed: busy ? null : submit,
              child: Text(
                busy ? 'wait...' : (registering ? 'register' : 'sign in'),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() {
                        registering = !registering;
                        error = '';
                      });
                    },
              child: Text(
                registering
                    ? 'already got an account? sign in'
                    : 'make an account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
