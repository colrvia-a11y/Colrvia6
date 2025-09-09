import 'package:flutter/material.dart';

import '../models/lighting_profile.dart';

/// Simple bottom sheet for choosing a lighting profile during photo import.
Future<LightingProfile?> showLightingProfilePicker(
  BuildContext context, {
  required LightingProfile current,
}) {
  LightingProfile temp = current;
  return showModalBottomSheet<LightingProfile>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Lighting Profile',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SegmentedButton<LightingProfile>(
                    segments: LightingProfile.values
                        .map((p) => ButtonSegment<LightingProfile>(
                              value: p,
                              label: Text(p.label),
                            ))
                        .toList(),
                    selected: {temp},
                    onSelectionChanged: (selection) {
                      setState(() {
                        temp = selection.first;
                      });
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(temp),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
