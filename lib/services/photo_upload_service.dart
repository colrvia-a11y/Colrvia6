// lib/services/photo_upload_service.dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:color_canvas/services/auth_service.dart';
import 'package:color_canvas/services/journey/journey_service.dart';

class PhotoUploadService {
  PhotoUploadService._();
  static final PhotoUploadService instance = PhotoUploadService._();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<XFile>> pickPhotos({int max = 6}) async {
    final res = await _picker.pickMultiImage();
    return res.take(max).toList();
  }

  Future<String> _ensureInterviewId() async {
    final journey = JourneyService.instance;
    String? id = journey.state.value?.artifacts['interviewId'] as String?;
    id ??= const Uuid().v4();
    await journey.setArtifact('interviewId', id);
    return id;
  }

  Future<List<String>> uploadAll(List<XFile> files, {void Function(double progress)? onProgress}) async {
    final user = await AuthService.instance.ensureSignedIn();
    final interviewId = await _ensureInterviewId();

    final urls = <String>[];
    double completed = 0;

    for (final xf in files) {
      final url = await _uploadOne(user.uid, interviewId, xf, (p) {
        completed += p; // p is 0..1 per file
        onProgress?.call((completed / files.length).clamp(0, 1));
      });
      urls.add(url);
    }
    return urls;
  }

  Future<String> _uploadOne(String uid, String interviewId, XFile xf, void Function(double) onOneProgress) async {
    // Compress to 85% quality and max 2560px (keeps detail, smaller size)
    final tmp = await _compress(xf);
    final ext = p.extension(xf.name).toLowerCase().replaceAll('.', '');
    final id = const Uuid().v4();
    final path = 'users/$uid/intake/$interviewId/$id.${ext.isEmpty ? 'jpg' : ext}';
    final ref = _storage.ref(path);

    final uploadTask = ref.putFile(
      File(tmp.path),
      SettableMetadata(contentType: 'image/$ext'),
    );

    uploadTask.snapshotEvents.listen((ev) {
      final t = ev.totalBytes == 0 ? 0.0 : ev.bytesTransferred / ev.totalBytes;
      onOneProgress(t);
    });

    await uploadTask.whenComplete(() {});
    final url = await ref.getDownloadURL();
    return url;
  }

  Future<XFile> _compress(XFile xf) async {
    final target = await FlutterImageCompress.compressWithFile(
      xf.path,
      quality: 85,
      minWidth: 2560,
      minHeight: 2560,
      keepExif: true,
      format: CompressFormat.jpeg,
    );
    if (target == null) return xf;
    final out = XFile.fromData(target, name: xf.name, mimeType: 'image/jpeg');
    return out;
  }
}
