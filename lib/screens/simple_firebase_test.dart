import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:color_canvas/firebase_config.dart';

class SimpleFirebaseTest extends StatefulWidget {
  const SimpleFirebaseTest({super.key});

  @override
  State<SimpleFirebaseTest> createState() => _SimpleFirebaseTestState();
}

class _SimpleFirebaseTestState extends State<SimpleFirebaseTest> {
  String _status = 'Testing Firebase...';
  String _result = '';
  final _emailController = TextEditingController(text: 'test@example.com');
  final _passwordController = TextEditingController(text: 'password123');

  @override
  void initState() {
    super.initState();
    _testFirebase();
  }

  Future<void> _testFirebase() async {
    try {
      // Step 1: Check if Firebase is initialized
      setState(() {
        _status = 'Step 1: Checking Firebase initialization...';
        _result = '';
      });
      
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseConfig.options,
        );
        setState(() => _result += '✅ Firebase initialized successfully\n');
      } else {
        setState(() => _result += '✅ Firebase already initialized\n');
      }

      // Step 2: Check FirebaseAuth instance
      setState(() => _status = 'Step 2: Checking FirebaseAuth...');
      final auth = FirebaseAuth.instance;
      setState(() => _result += '✅ FirebaseAuth instance created\n');
      setState(() => _result += 'App: ${auth.app.name}\n');
      setState(() => _result += 'Project ID: ${auth.app.options.projectId}\n');

      // Step 3: Test basic auth operations
      setState(() => _status = 'Step 3: Testing authentication...');
      
      // Sign out first to clean state
      await auth.signOut();
      setState(() => _result += '✅ Sign out successful\n');

      setState(() => _status = 'Ready to test sign in/up');
      
    } catch (e) {
      setState(() {
        _status = 'Firebase test failed';
        _result += '❌ Error: $e\n';
      });
    }
  }

  Future<void> _testSignUp() async {
    try {
      setState(() => _status = 'Testing sign up...');
      
      final auth = FirebaseAuth.instance;
      final credential = await auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      
      setState(() {
        _result += '✅ Sign up successful!\n';
        _result += 'User ID: ${credential.user?.uid}\n';
        _result += 'Email: ${credential.user?.email}\n';
        _status = 'Sign up completed';
      });
      
    } catch (e) {
      setState(() {
        _result += '❌ Sign up failed: $e\n';
        _status = 'Sign up failed';
      });
    }
  }

  Future<void> _testSignIn() async {
    try {
      setState(() => _status = 'Testing sign in...');
      
      final auth = FirebaseAuth.instance;
      final credential = await auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      
      setState(() {
        _result += '✅ Sign in successful!\n';
        _result += 'User ID: ${credential.user?.uid}\n';
        _result += 'Email: ${credential.user?.email}\n';
        _status = 'Sign in completed';
      });
      
    } catch (e) {
      setState(() {
        _result += '❌ Sign in failed: $e\n';
        _status = 'Sign in failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: $_status',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                ElevatedButton(
                  onPressed: _testSignUp,
                  child: const Text('Test Sign Up'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _testSignIn,
                  child: const Text('Test Sign In'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _testFirebase,
                  child: const Text('Retest'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _result,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
