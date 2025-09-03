import 'package:cloud_firestore/cloud_firestore.dart';

class VisualizerJob {
  final String id;
  final String uid;
  final String mode; // 'photo' or 'mockup'
  final String? inputGsPath;
  final String roomType;
  final List<String> surfaces; // e.g., ['walls','cabinets','trim']
  final List<String> variants; // HEX strings
  final String status; // running|complete|error
  final DateTime createdAt;
  final DateTime updatedAt;

  VisualizerJob({
    required this.id,
    required this.uid,
    required this.mode,
    this.inputGsPath,
    required this.roomType,
    required this.surfaces,
    required this.variants,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VisualizerJob.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return VisualizerJob(
      id: doc.id,
      uid: d['uid'],
      mode: d['mode'] ?? 'photo',
      inputGsPath: d['inputGsPath'],
      roomType: d['roomType'] ?? 'interior room',
      surfaces: List<String>.from(d['surfaces'] ?? const ['walls']),
      variants:
          List<String>.from(d['variantHexes'] ?? d['variants'] ?? const []),
      status: d['status'] ?? 'running',
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      updatedAt: (d['updatedAt'] as Timestamp).toDate(),
    );
  }
}

class VisualizerRender {
  final String hex;
  final String gsPath;
  final String downloadUrl;

  VisualizerRender(
      {required this.hex, required this.gsPath, required this.downloadUrl});

  factory VisualizerRender.fromMap(Map<String, dynamic> m) => VisualizerRender(
        hex: m['hex'] ?? '#000000',
        gsPath: m['filePath'] ?? '',
        downloadUrl: m['downloadUrl'] ?? '',
      );
}
