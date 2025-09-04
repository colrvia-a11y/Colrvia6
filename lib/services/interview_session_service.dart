// lib/services/interview_session_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/interview_session.dart';
import '../models/interview_turn.dart';

class InterviewSessionService {
  InterviewSession createSession(List<InterviewTurn> turns) {
    final doc =
        FirebaseFirestore.instance.collection('interviewSessions').doc();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final now = DateTime.now();

    return InterviewSession(
      id: doc.id,
      userId: userId,
      turns: turns,
      startedAt: now,
      updatedAt: now,
    );
  }

  Future<void> saveSession(InterviewSession session) async {
    await FirebaseFirestore.instance
        .collection('interviewSessions')
        .doc(session.id)
        .set(session.toJson());
  }
}

