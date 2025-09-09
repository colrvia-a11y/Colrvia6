import 'package:cloud_firestore/cloud_firestore.dart';

class InterviewSessionSummary {
  final String id;
  final String userId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSec;
  final String? status;
  final String? mode; // e.g., 'realtime', 'text'
  final String? model;
  final String? voice;

  InterviewSessionSummary({
    required this.id,
    required this.userId,
    this.startedAt,
    this.endedAt,
    this.durationSec,
    this.status,
    this.mode,
    this.model,
    this.voice,
  });

  factory InterviewSessionSummary.fromSnap(
      DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const <String, dynamic>{};
    DateTime? tsToDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {}
      }
      return null;
    }

    return InterviewSessionSummary(
      id: d.id,
      userId: (m['userId'] as String?) ?? 'anonymous',
      startedAt: tsToDate(m['startedAt']),
      endedAt: tsToDate(m['endedAt']),
      durationSec: (m['durationSec'] is int) ? m['durationSec'] as int : null,
      status: m['status'] as String?,
      mode: m['mode'] as String?,
      model: m['model'] as String?,
      voice: m['voice'] as String?,
    );
  }
}
