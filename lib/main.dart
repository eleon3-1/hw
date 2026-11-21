import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'firebase_options.dart';
import 'authScreen.dart';
import 'boardService.dart';
import 'boardScreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: SplashScreen()));
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late Future<FirebaseApp> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

    Future<FirebaseApp> _initialize() async {
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    const useEmulators = bool.fromEnvironment('USE_EMULATORS');

    if (useEmulators) {
      const host = kIsWeb ? '127.0.0.1' : '10.0.2.2';

      await AuthService.connectEmulator(host);
      BoardService.connectEmulator(host);
    }

    return app;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('firebase didnt start'),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _initialization = _initialize();
                      });
                    },
                    child: const Text('retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
  return const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Msgboard',
            style: TextStyle(fontSize: 28),
          ),
          SizedBox(height: 16),
          CircularProgressIndicator(),
        ],
      ),
    ),
  );
}

        return const AuthGate();
      },
    );
  }
}

class AuthService {
  static Future<void> connectEmulator(String host) async {
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final Stream<User?> authState = _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register(
    String email,
    String password, {
    required String firstName,
    required String lastName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await BoardService().saveUserRecord(
      uid: credential.user!.uid,
      firstName: firstName,
      lastName: lastName,
    );

    return credential;
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: auth.authState,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('cant check sign in')),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return AuthScreen(auth: auth);
        }

        return BoardScreen(auth: auth);
      },
    );
  }
}
