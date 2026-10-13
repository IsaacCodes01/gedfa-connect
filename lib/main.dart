import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Phase0TestScreen(),
    );
  }
}

class Phase0TestScreen extends StatefulWidget {
  const Phase0TestScreen({super.key});

  @override
  State<Phase0TestScreen> createState() => _Phase0TestScreenState();
}

class _Phase0TestScreenState extends State<Phase0TestScreen> {
  String _message = 'Press a button to test Firestore';

  // TASK 1: write a tray, then read it back
  Future<void> _runTest() async {
    setState(() {
      _message = 'Working...';
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('phase0Test')
          .doc('hello');

      await docRef.set({
        'text': 'Hello from GEDFA Connect',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final snapshot = await docRef.get();
      final data = snapshot.data();

      setState(() {
        _message = 'Read back from Firestore:\n${data?['text']}';
      });
    } catch (e) {
      setState(() {
        _message = 'Error: $e';
      });
    }
  }

  // TASK 2: only look at the shelf, write nothing
  Future<void> _readTest() async {
    setState(() {
      _message = 'Reading...';
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('phase0Test')
          .doc('hello')
          .get();
      final data = snapshot.data();

      setState(() {
        _message = 'Read only:\n${data?['text']}';
      });
    } catch (e) {
      setState(() {
        _message = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phase 0 Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _readTest,
                child: const Text('Read only'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _runTest,
        child: const Icon(Icons.cloud_upload),
      ),
    );
  }
}