// lib/screens/interview_review_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/services/interview_engine.dart';

class InterviewReviewScreen extends StatefulWidget {
  final InterviewEngine engine; // already loaded & seeded
  const InterviewReviewScreen({super.key, required this.engine});

  @override
  State<InterviewReviewScreen> createState() => _InterviewReviewScreenState();
}

class _InterviewReviewScreenState extends State<InterviewReviewScreen> {
  late Map<String, dynamic> _answers;

  @override
  void initState() {
    super.initState();
    _answers = Map.of(widget.engine.answers);
  }

  // Required prompts are those marked required & visible under current answers
  List<InterviewPrompt> _missingRequired() {
    final visibleRequired =
        widget.engine.visiblePrompts.where((p) => p.required).toList();
    final missing = <InterviewPrompt>[];
    for (final p in visibleRequired) {
      final v = _answers[p.id];
      if (v == null) {
        missing.add(p);
        continue;
      }
      if (v is String && v.trim().isEmpty) {
        missing.add(p);
        continue;
      }
      if (v is List && v.isEmpty) {
        missing.add(p);
        continue;
      }
    }
    return missing;
  }

  Future<void> _generate() async {
    // Persist and advance the journey
    await JourneyService.instance.setArtifact('answers', _answers);
    await AnalyticsService.instance
        .logEvent('interview_review_confirmed');
    await JourneyService.instance.completeCurrentStep();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nice! Generating your palette…')),
      );
      Navigator.of(context).maybePop(); // back to Guided timeline
      Navigator.of(context).maybePop(); // close InterviewScreen if still on stack
    }
  }

  void _editInChat(String id) {
    Navigator.of(context).pop({'jumpTo': id}); // signal parent to deep-link back
  }

  Widget _section(String title, List<_Row> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final r in rows) _rowTile(r),
          ],
        ),
      ),
    );
  }

  Widget _rowTile(_Row r) {
    final value = r.displayValue;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(r.label),
      subtitle: value.isEmpty ? const Text('—') : Text(value),
      trailing: TextButton.icon(
        onPressed: () => _editInChat(r.id),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
    );
  }

  String _labelForValue(InterviewPrompt p, dynamic value) {
    if (value == null) return '';
    if (p.type == InterviewPromptType.multiSelect && value is List) {
      if (p.options.isEmpty) {
        return value.join(', ');
      }
      return value
          .map((v) => p.options
              .firstWhere((o) => o.value == v, orElse: () => p.options.first)
              .label)
          .join(', ');
    }
    if (value is String) {
      if (p.options.isEmpty) return value;
      final opt = p.options
          .where((o) => o.value == value)
          .cast<InterviewPromptOption?>()
          .firstWhere((e) => e != null, orElse: () => null);
      return opt?.label ?? value;
    }
    return value.toString();
  }

  List<_Row> _rowsForIds(List<String> ids) {
    final rows = <_Row>[];
    for (final id in ids) {
      final p = widget.engine.byId(id);
      if (p == null) continue;
      if (!widget.engine.isPromptVisible(id)) continue;
      final v = _answers[id];
      final label = p.title;
      final display = _labelForValue(p, v);
      rows.add(_Row(id: id, label: label, displayValue: display));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final roomType = _answers['roomType'] as String?;

    final core = _rowsForIds([
      'roomType',
      'usage',
      'moodWords',
      'daytimeBrightness',
      'bulbColor',
      'boldDarkerSpot',
      'brandPreference',
    ]);

    final existing = _rowsForIds([
      'existingElements.floorLook',
      'existingElements.floorLookOtherNote',
      'existingElements.bigThingsToMatch',
      'existingElements.metals',
      'existingElements.mustStaySame',
    ]);

    final comfort = _rowsForIds([
      'colorComfort.overallVibe',
      'colorComfort.warmCoolFeel',
      'colorComfort.contrastLevel',
      'colorComfort.popColor',
    ]);

    final finishes = _rowsForIds([
      'finishes.wallsFinishPriority',
      'finishes.trimDoorsFinish',
      'finishes.specialNeeds',
    ]);

    // Room-specific blocks
    final roomMap = <String, List<String>>{
      'kitchen': [
        'roomSpecific.cabinets',
        'roomSpecific.cabinetsCurrentColor',
        'roomSpecific.island',
        'roomSpecific.countertopsDescription',
        'roomSpecific.backsplash',
        'roomSpecific.backsplashDescribe',
        'roomSpecific.appliances',
        'roomSpecific.wallFeel',
        'roomSpecific.darkerSpots',
      ],
      'bathroom': [
        'roomSpecific.tileMainColor',
        'roomSpecific.tileColorWhich',
        'roomSpecific.vanityTop',
        'roomSpecific.showerSteamLevel',
        'roomSpecific.fixtureMetal',
        'roomSpecific.goal',
        'roomSpecific.darkerVanityOrDoor',
      ],
      'bedroom': [
        'roomSpecific.sleepFeel',
        'roomSpecific.beddingColors',
        'roomSpecific.headboard',
        'roomSpecific.windowTreatments',
        'roomSpecific.darkerWallBehindBed',
      ],
      'livingRoom': [
        'roomSpecific.sofaColor',
        'roomSpecific.rugMainColors',
        'roomSpecific.fireplace',
        'roomSpecific.fireplaceDetail',
        'roomSpecific.tvWall',
        'roomSpecific.builtInsOrDoorColor',
      ],
      'diningRoom': [
        'roomSpecific.tableWoodTone',
        'roomSpecific.chairs',
        'roomSpecific.lightFixtureMetal',
        'roomSpecific.feeling',
        'roomSpecific.darkerBelowOrOneWall',
      ],
      'office': [
        'roomSpecific.workMood',
        'roomSpecific.screenGlare',
        'roomSpecific.deeperLibraryWallsOk',
        'roomSpecific.colorBookshelvesOrBuiltIns',
      ],
      'kidsRoom': [
        'roomSpecific.mood',
        'roomSpecific.mainFabricToyColors',
        'roomSpecific.superWipeableWalls',
        'roomSpecific.smallColorPopOk',
      ],
      'laundryMudroom': [
        'roomSpecific.traffic',
        'roomSpecific.cabinetsShelving',
        'roomSpecific.cabinetsColor',
        'roomSpecific.hideDirtOrBrightClean',
        'roomSpecific.doorColorMomentOk',
      ],
      'entryHall': [
        'roomSpecific.naturalLight',
        'roomSpecific.stairsBanister',
        'roomSpecific.woodTone',
        'roomSpecific.paintColor',
        'roomSpecific.feel',
        'roomSpecific.doorColorMoment',
      ],
      'other': ['roomSpecific.describeRoom'],
    };

    final roomRows = _rowsForIds(roomMap[roomType] ?? const []);

    // Guardrails and Photos
    final guardrails = _rowsForIds(['guardrails.mustHaves', 'guardrails.hardNos']);
    final photos = _rowsForIds(['photos']);

    final missing = _missingRequired();

    return Scaffold(
      appBar: AppBar(title: const Text('Review answers')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (missing.isNotEmpty)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Missing required',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer),
                      ),
                      const SizedBox(height: 8),
                      for (final p in missing)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(p.title),
                          trailing: TextButton(
                            onPressed: () => _editInChat(p.id),
                            child: const Text('Fill now'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            _section('Basics', core),
            if (roomRows.isNotEmpty) _section('Room details', roomRows),
            _section('Existing elements', existing),
            _section('Color comfort', comfort),
            _section('Finishes', finishes),
            _section('Guardrails', guardrails),
            _photosSection(photos),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: missing.isNotEmpty ? null : _generate,
              icon: const Icon(Icons.palette_outlined),
              label: const Text('Looks good — Generate my palette'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photosSection(List<_Row> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final photoRow = rows.firstWhere((r) => r.id == 'photos',
        orElse: () =>
            _Row(id: 'photos', label: 'Photos', displayValue: ''));

    final val = widget.engine.answers['photos'];
    final uris = (val is List) ? val.cast<String>() : const <String>[];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (uris.isEmpty) const Text('—'),
            if (uris.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: uris
                    .map((u) => ActionChip(
                          label: Text(_truncate(u)),
                          onPressed: () => launchUrl(Uri.parse(u),
                              mode: LaunchMode.externalApplication),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _editInChat('photos'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _truncate(String s) {
    if (s.length <= 36) return s;
    return s.substring(0, 16) + '…' + s.substring(s.length - 12);
  }
}

class _Row {
  final String id;
  final String label;
  final String displayValue;
  _Row({required this.id, required this.label, required this.displayValue});
}
