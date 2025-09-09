import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureMicPermission() async {
  final status = await Permission.microphone.request();
  return status.isGranted;
}
