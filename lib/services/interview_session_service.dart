// lib/services/interview_session_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/interview_session.dart';
import '../models/interview_session_summary.dart';
import '../models/interview_turn.dart';
import 'transcript_recorder.dart';

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

  /// Persist a session created from a TranscriptRecorder's events and also
  /// upload the raw JSON transcript to Cloud Storage. Returns the saved doc id.
  Future<String> saveFromTranscript(TranscriptRecorder recorder) async {
    final turns = recorder.toInterviewTurns();
    final session = createSession(turns);
    await saveSession(session);
    try {
      await recorder.uploadJson(sessionId: session.id);
    } catch (_) {
      // Non-fatal: storage upload may fail independently
    }
    return session.id;
  }

  /// Returns a stream of the current user's interview sessions, most recent first.
  Stream<List<InterviewSessionSummary>> watchCurrentUserSessions({int limit = 25}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      // Emit empty list if not signed in
      return const Stream<List<InterviewSessionSummary>>.empty();
    }
    final q = FirebaseFirestore.instance
        .collection('interviewSessions')
        .where('userId', isEqualTo: uid)
        .orderBy('startedAt', descending: true)
        .limit(limit);
    return q.snapshots().map((s) => s.docs.map((d) => InterviewSessionSummary.fromSnap(d)).toList());
  }

  /// One-shot fetch of the current user's recent interview sessions.
  Future<List<InterviewSessionSummary>> getCurrentUserSessions({int limit = 25}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return <InterviewSessionSummary>[];
    final snap = await FirebaseFirestore.instance
        .collection('interviewSessions')
        .where('userId', isEqualTo: uid)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => InterviewSessionSummary.fromSnap(d)).toList();
  }
}

