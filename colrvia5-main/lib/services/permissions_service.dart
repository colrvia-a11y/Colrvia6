import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'analytics_service.dart';

/// Lightweight wrapper to show permission microcopy before requesting access.
class PermissionsService {
  static Future<bool> confirmAndRequest(
      BuildContext context, Permission permission) async {
    final type = permission == Permission.camera ? 'camera' : 'photos';
    final titles = {
      'camera': 'Camera Access',
      'photos': 'Photo Access',
    };
    final messages = {
      'camera':
          'We use your camera only to capture photos of your space. No media leaves your device without your consent.',
      'photos':
          'We need access to your photo library to visualize your room. Images stay private unless you choose to share.',
    };
    // Show microcopy dialog
    AnalyticsService.instance.permissionMicrocopyShown(type);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titles[type]!),
        content: Text(messages[type]!),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (proceed != true) return false;
    // Request permission
    AnalyticsService.instance.permissionRequested(type);
    final status = await permission.request();
    return status.isGranted;
  }
}
