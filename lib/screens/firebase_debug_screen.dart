import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_config.dart';

class FirebaseDebugScreen extends StatefulWidget {
  const FirebaseDebugScreen({super.key});

  @override
  State<FirebaseDebugScreen> createState() => _FirebaseDebugScreenState();
}

class _FirebaseDebugScreenState extends State<FirebaseDebugScreen> {
  String _status = 'Checking Firebase...';
  String _details = '';

  @override
  void initState() {
    super.initState();
    _checkFirebase();
  }

  Future<void> _checkFirebase() async {
    try {
      // Check if Firebase is initialized
      await Firebase.initializeApp(
        options: FirebaseConfig.options,
      );

      setState(() {
        _status = 'Firebase initialized successfully';
        _details = 'Project ID: ${Firebase.app().options.projectId}\n'
            'App ID: ${Firebase.app().options.appId}\n'
            'API Key: ${Firebase.app().options.apiKey.substring(0, 20)}...';
      });

      // Test FirebaseAuth
      try {
        final auth = FirebaseAuth.instance;
        setState(() {
          _details += '\n\nFirebaseAuth: ${auth.app.name}';
          _details += '\nCurrent User: ${auth.currentUser?.uid ?? "None"}';
        });

        // Try to create a test user (this will fail with specific error)
        try {
          await auth.createUserWithEmailAndPassword(
            email: 'test@example.com',
            password: 'testpass123',
          );
        } catch (e) {
          setState(() {
            _details += '\n\nAuth Test Error: $e';
          });
        }
      } catch (e) {
        setState(() {
          _status = 'Firebase Auth Error';
          _details += '\n\nFirebaseAuth Error: $e';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Firebase Initialization Failed';
        _details = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Debug'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _status,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _details,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _checkFirebase,
              child: const Text('Recheck Firebase'),
            ),
          ],
        ),
      ),
    );
  }
}
