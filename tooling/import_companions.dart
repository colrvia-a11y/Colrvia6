// tooling/import_companions.dart
// Usage: dart import_companions.dart path/to/file.json
// File format: [{"id":"color1","similarIds":[...],{"id":"color2","similarIds":[...],"companionIds":[...]}]

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    debugPrint('Usage: dart import_companions.dart <file>');
    exit(1);
  }
  final file = File(args[0]);
  if (!await file.exists()) {
    debugPrint('File not found: ${args[0]}');
    exit(1);
  }
  final data = jsonDecode(await file.readAsString()) as List;

  // Initialize Firebase
  await Firebase.initializeApp();
  final db = FirebaseFirestore.instance;

  int updatedCount = 0;
  int errorCount = 0;
  final batch = db.batch();

  for (final item in data) {
    try {
      final id = item['id'] as String;
      final similarIds = (item['similarIds'] as List).cast<String>();
      final companionIds = (item['companionIds'] as List).cast<String>();

      final docRef = db.collection('paints').doc(id);
      batch.update(docRef, {
        'similarIds': similarIds,
        'companionIds': companionIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      updatedCount++;
    } catch (e) {
      debugPrint('Error processing item: $item, error: $e');
      errorCount++;
    }
  }

  try {
    await batch.commit();
    debugPrint('catalog_enriched(updated: $updatedCount, errors: $errorCount)');
  } catch (e) {
    debugPrint('Error committing batch: $e');
    errorCount = data.length; // Assume all failed if batch commit fails
    debugPrint('catalog_enriched(updated: 0, errors: $errorCount)');
  }
}
