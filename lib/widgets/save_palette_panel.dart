import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/services/auth_guard.dart';
import 'package:color_canvas/services/user_prefs_service.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:color_canvas/screens/visualizer_screen.dart';

typedef CreatePaletteFn = Future<String> Function({
  required String userId,
  required String name,
  required List<PaletteColor> colors,
  List<String> tags,
  String notes,
});
typedef CreateProjectFn = Future<String> Function({
  required String ownerId,
  String? title,
  String? activePaletteId,
  List<String> paletteIds,
});
typedef AttachPaletteFn = Future<void> Function(
    String projectId, String paletteId);
typedef SetLastProjectFn = Future<void> Function(
    String projectId, String screen);
typedef EnsureSignedInFn = Future<void> Function(BuildContext context);
typedef GetUidFn = String? Function();

@visibleForTesting
CreatePaletteFn createPaletteFn = FirebaseService.createPalette;
@visibleForTesting
CreateProjectFn createProjectFn = ProjectService.create;
@visibleForTesting
AttachPaletteFn attachPaletteFn = ProjectService.attachPalette;
@visibleForTesting
SetLastProjectFn setLastProjectFn = UserPrefsService.setLastProject;
@visibleForTesting
EnsureSignedInFn ensureSignedInFn = AuthGuard.ensureSignedIn;
@visibleForTesting
GetUidFn getUidFn = () => FirebaseAuth.instance.currentUser?.uid;

class SavePalettePanel extends StatefulWidget {
  final String? projectId;
  final List<Paint> paints;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const SavePalettePanel({
    super.key,
    this.projectId,
    required this.paints,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<SavePalettePanel> createState() => _SavePalettePanelState();
}

class _SavePalettePanelState extends State<SavePalettePanel> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final List<String> _tags = [];
  final _tagController = TextEditingController();
  bool _isSaving = false;

  static const List<String> quickTags = [
    'Living Room',
    'Bedroom',
    'Kitchen',
    'Bathroom',
    'Neutral',
    'Bold',
    'Warm',
    'Cool',
    'Modern',
    'Classic'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
      });
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _savePalette() async {
    if (widget.paints.isEmpty) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a palette name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ensureSignedInFn(context);
      final uid = getUidFn();
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to save palettes.')),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      debugPrint(
          'Attempting to save palette for userId: $uid to collection: palettes');

      final palette = UserPalette(
        id: '', // Will be set by FirebaseService
        userId: uid, // Will be set by FirebaseService
        name: _nameController.text.trim(),
        colors: widget.paints
            .asMap()
            .entries
            .map((entry) => PaletteColor(
                  paintId: entry.value.id,
                  locked: false,
                  position: entry.key,
                  brand: entry.value.brandName,
                  name: entry.value.name,
                  hex: entry.value.hex,
                  code: entry.value.code,
                ))
            .toList(),
        tags: _tags,
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final savedPaletteId = await createPaletteFn(
        userId: uid,
        name: palette.name,
        colors: palette.colors,
        tags: palette.tags,
        notes: palette.notes,
      );

      if (mounted) {
        // Track successful save
        AnalyticsService.instance.logEvent('palette_saved', {
          'palette_name': palette.name,
          'color_count': palette.colors.length,
          'tags': palette.tags,
        });

        String? projectId =
            widget.projectId; // Use existing projectId if available

        if (projectId == null) {
          // Create a new project if none exists
          projectId = await createProjectFn(
            ownerId: uid,
            title: palette.name,
            activePaletteId: savedPaletteId,
            paletteIds: const [],
          );
        } else {
          // Attach palette to existing project
          await attachPaletteFn(projectId, savedPaletteId);
        }

        // Persist lastOpenedProjectId
        await setLastProjectFn(projectId, 'roller');

        final journey = JourneyService.instance;
        final curr = journey.state.value;
        if (curr != null && curr.projectId == null) {
          journey.state.value = curr.copyWith(projectId: projectId);
        }
        await journey
            .completeCurrentStep(artifacts: {'paletteId': savedPaletteId});

        // Show subtle success snackbar
        widget.onSaved(); // Close save panel first
        // After closing, the widget might be disposed; guard context use.
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Saved to your Color Story'),
            action: SnackBarAction(
              label: 'Preview',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const VisualizerScreen(),
                ));
              },
            ),
          ),
        );
        AnalyticsService.instance
            .logRollerSaveToProject(projectId, savedPaletteId);
      }
    } catch (e) {
      debugPrint('Save palette failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Save Palette',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),

          // Preview strip
          Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: widget.paints.map((paint) {
                return Expanded(
                  child: Container(
                    color: Color(
                        int.parse(paint.hex.replaceAll('#', ''), radix: 16) |
                            0xFF000000),
                    child: Container(), // Empty container for color display
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Name field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Palette Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Quick tags
          Text('Quick Tags', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: quickTags.map((tag) {
              return FilterChip(
                label: Text(tag),
                selected: _tags.contains(tag),
                onSelected: (selected) {
                  if (selected) {
                    _addTag(tag);
                  } else {
                    _removeTag(tag);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Custom tag input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    labelText: 'Add Custom Tag',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) => _addTag(value.trim()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _addTag(_tagController.text.trim()),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Current tags
          if (_tags.isNotEmpty) ...[
            Text('Selected Tags',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _tags.map((tag) {
                return Chip(
                  label: Text(tag),
                  onDeleted: () => _removeTag(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Notes field
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _isSaving ? null : _savePalette,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Palette'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
