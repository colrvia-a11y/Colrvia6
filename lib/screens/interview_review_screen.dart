// lib/screens/interview_review_screen.dart
import 'package:flutter/material.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/interview_engine.dart';
import 'package:color_canvas/services/interview_shared_engine.dart' as shared;
import 'package:color_canvas/widgets/photo_picker_inline.dart';
import 'package:color_canvas/services/palette_service.dart';
import 'package:color_canvas/screens/palette_reveal_screen.dart';
import '../theme.dart';

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
    widget.engine.addListener(_onEngine);
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngine);
    super.dispose();
  }

  void _onEngine() {
    // Keep local snapshot in sync (e.g., when branching changes visibility)
    setState(() => _answers = Map.of(widget.engine.answers));
  }

  // Required prompts are those marked required & visible under current answers
  List<InterviewPrompt> _missingRequired() {
    final visibleRequired = widget.engine.visiblePrompts.where((p) => p.required).toList();
    final missing = <InterviewPrompt>[];
    for (final p in visibleRequired) {
      final v = _answers[p.id];
      if (v == null) { missing.add(p); continue; }
      if (v is String && v.trim().isEmpty) { missing.add(p); continue; }
      if (v is List && v.isEmpty) { missing.add(p); continue; }
    }
    return missing;
  }

  Future<void> _generate() async {
    final answers = Map<String, dynamic>.from(_answers);

    setState(() {}); // optional: show loading state on button

    // Persist the voice/text interview session (if any) then end it to avoid stale turns.
    await shared.InterviewEngine().saveSessionToFirestore();
    shared.InterviewEngine().endSession();

    // Generate palette from the final answers and advance the Journey, persisting answers.
    await PaletteService.instance.generateFromAnswers(answers);
    await JourneyService.instance.completeCurrentStep(artifacts: {
      'answers': answers,
    });

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PaletteRevealScreen()),
    );
  }

  void _editInChat(String id) {
    Navigator.of(context).pop({'jumpTo': id});
  }

  Future<void> _editInline(String id) async {
    final prompt = widget.engine.byId(id);
    if (prompt == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _PromptEditorSheet(
          prompt: prompt,
          initialValue: _answers[id],
          onSave: (val) {
            widget.engine.setAnswer(id, val);
            setState(() => _answers = Map.of(widget.engine.answers));
          },
        ),
      ),
    );
  }

  Widget _section(String title, List<_Row> rows, {bool editable = true}) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(AppDims.gap * 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final r in rows) _rowTile(r, editable: editable),
          ],
        ),
      ),
    );
  }

  Widget _rowTile(_Row r, {bool editable = true}) {
    final value = r.displayValue;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(r.label),
      subtitle: value.isEmpty ? const Text('—') : Text(value),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (editable)
            Semantics(
              button: true,
              label: 'Quick edit \\${r.label}',
              child: TextButton.icon(
                onPressed: () => _editInline(r.id),
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Quick edit'),
              ),
            ),
          if (editable) const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Edit \\${r.label} in chat',
            child: TextButton.icon(
              onPressed: () => _editInChat(r.id),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit in chat'),
            ),
          ),
        ],
      ),
    );
  }

  String _labelForValue(InterviewPrompt p, dynamic value) {
    if (value == null) return '';
    if (p.type == InterviewPromptType.multiSelect && value is List) {
      if (p.options.isEmpty) {
        return value.join(', ');
      }
      return value.map((v) => p.options.firstWhere((o) => o.value == v, orElse: () => p.options.first).label).join(', ');
    }
    if (value is String) {
      if (p.options.isEmpty) return value;
      final opt = p.options.where((o) => o.value == value).cast<InterviewPromptOption?>().firstWhere((e) => e != null, orElse: () => null);
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
      'roomType','usage','moodWords','daytimeBrightness','bulbColor','boldDarkerSpot','brandPreference',
    ]);

    final existing = _rowsForIds([
      'existingElements.floorLook','existingElements.floorLookOtherNote','existingElements.bigThingsToMatch','existingElements.metals','existingElements.mustStaySame',
    ]);

    final comfort = _rowsForIds([
      'colorComfort.overallVibe','colorComfort.warmCoolFeel','colorComfort.contrastLevel','colorComfort.popColor',
    ]);

    final finishes = _rowsForIds([
      'finishes.wallsFinishPriority','finishes.trimDoorsFinish','finishes.specialNeeds',
    ]);

    // Room-specific blocks
    final roomMap = <String, List<String>>{
      'kitchen': ['roomSpecific.cabinets','roomSpecific.cabinetsCurrentColor','roomSpecific.island','roomSpecific.countertopsDescription','roomSpecific.backsplash','roomSpecific.backsplashDescribe','roomSpecific.appliances','roomSpecific.wallFeel','roomSpecific.darkerSpots'],
      'bathroom': ['roomSpecific.tileMainColor','roomSpecific.tileColorWhich','roomSpecific.vanityTop','roomSpecific.showerSteamLevel','roomSpecific.fixtureMetal','roomSpecific.goal','roomSpecific.darkerVanityOrDoor'],
      'bedroom': ['roomSpecific.sleepFeel','roomSpecific.beddingColors','roomSpecific.headboard','roomSpecific.windowTreatments','roomSpecific.darkerWallBehindBed'],
      'livingRoom': ['roomSpecific.sofaColor','roomSpecific.rugMainColors','roomSpecific.fireplace','roomSpecific.fireplaceDetail','roomSpecific.tvWall','roomSpecific.builtInsOrDoorColor'],
      'diningRoom': ['roomSpecific.tableWoodTone','roomSpecific.chairs','roomSpecific.lightFixtureMetal','roomSpecific.feeling','roomSpecific.darkerBelowOrOneWall'],
      'office': ['roomSpecific.workMood','roomSpecific.screenGlare','roomSpecific.deeperLibraryWallsOk','roomSpecific.colorBookshelvesOrBuiltIns'],
      'kidsRoom': ['roomSpecific.mood','roomSpecific.mainFabricToyColors','roomSpecific.superWipeableWalls','roomSpecific.smallColorPopOk'],
      'laundryMudroom': ['roomSpecific.traffic','roomSpecific.cabinetsShelving','roomSpecific.cabinetsColor','roomSpecific.hideDirtOrBrightClean','roomSpecific.doorColorMomentOk'],
      'entryHall': ['roomSpecific.naturalLight','roomSpecific.stairsBanister','roomSpecific.woodTone','roomSpecific.paintColor','roomSpecific.feel','roomSpecific.doorColorMoment'],
      'other': ['roomSpecific.describeRoom'],
    };

    final roomRows = _rowsForIds(roomMap[roomType] ?? const []);

    // Guardrails and Photos
    final guardrails = _rowsForIds(['guardrails.mustHaves','guardrails.hardNos']);
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
                  padding: const EdgeInsets.all(AppDims.gap * 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Missing required', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer)),
                      const SizedBox(height: 8),
                      for (final p in missing)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(p.title),
                          trailing: Wrap(spacing: 8, children: [
                            TextButton(onPressed: () => _editInline(p.id), child: const Text('Quick edit')),
                            TextButton(onPressed: () => _editInChat(p.id), child: const Text('Edit in chat')),
                          ]),
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
    final urls = (_answers['photos'] as List?)?.cast<String>() ?? const <String>[];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(AppDims.gap * 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            PhotoPickerInline(
              value: urls,
              onChanged: (next) async {
                _answers['photos'] = next;
                widget.engine.setAnswer('photos', next);
                await JourneyService.instance.setArtifact('answers', widget.engine.answers);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

}

class _Row {
  final String id;
  final String label;
  final String displayValue;
  _Row({required this.id, required this.label, required this.displayValue});
}

// === Bottom sheet editor ===
class _PromptEditorSheet extends StatefulWidget {
  final InterviewPrompt prompt;
  final dynamic initialValue;
  final void Function(dynamic) onSave;
  const _PromptEditorSheet({required this.prompt, required this.initialValue, required this.onSave});

  @override
  State<_PromptEditorSheet> createState() => _PromptEditorSheetState();
}

class _PromptEditorSheetState extends State<_PromptEditorSheet> {
  late dynamic _value;

  @override
  void initState() {
    super.initState();
    _value = _clone(widget.initialValue);
  }

  dynamic _clone(dynamic v) {
    if (v is List) return [...v];
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prompt;
    final title = p.title;

    Widget editor;
    switch (p.type) {
      case InterviewPromptType.singleSelect:
        editor = _SingleSelectEditor(prompt: p, value: (_value as String?), onChanged: (v) => setState(() => _value = v));
        break;
      case InterviewPromptType.multiSelect:
        if (p.options.isEmpty) {
          editor = _FreeListEditor(values: (_value as List?)?.cast<String>() ?? const [], onChanged: (v) => setState(() => _value = v), minItems: p.minItems, maxItems: p.maxItems);
        } else {
          editor = _MultiSelectEnumEditor(prompt: p, values: (_value as List?)?.cast<String>() ?? const [], onChanged: (v) => setState(() => _value = v), minItems: p.minItems, maxItems: p.maxItems);
        }
        break;
      case InterviewPromptType.freeText:
        editor = _FreeTextEditor(value: (_value as String?) ?? '', onChanged: (v) => setState(() => _value = v));
        break;
      case InterviewPromptType.yesNo:
        editor = _YesNoEditor(value: (_value as String?), onChanged: (v) => setState(() => _value = v));
        break;
    }

    final canSave = () {
      if (!p.required) return true;
      if (_value == null) return false;
      if (_value is String && (_value as String).trim().isEmpty) return false;
      if (_value is List && (_value as List).isEmpty) return false;
      return true;
    }();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            editor,
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: canSave ? () { widget.onSave(_value); Navigator.of(context).maybePop(); } : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleSelectEditor extends StatelessWidget {
  final InterviewPrompt prompt;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _SingleSelectEditor({required this.prompt, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: value,
      onChanged: onChanged,
      child: Column(
        children: prompt.options.map((o) => RadioListTile<String>(
          value: o.value,
          title: Text(o.label),
        )).toList(),
      ),
    );
  }
}

class _MultiSelectEnumEditor extends StatefulWidget {
  final InterviewPrompt prompt;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final int? minItems;
  final int? maxItems;
  const _MultiSelectEnumEditor({required this.prompt, required this.values, required this.onChanged, this.minItems, this.maxItems});

  @override
  State<_MultiSelectEnumEditor> createState() => _MultiSelectEnumEditorState();
}

class _MultiSelectEnumEditorState extends State<_MultiSelectEnumEditor> {
  late final List<String> _selected = [...widget.values];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.prompt.options.map((o) => CheckboxListTile(
              value: _selected.contains(o.value),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    if (widget.maxItems == null || _selected.length < widget.maxItems!) {
                      _selected.add(o.value);
                    }
                  } else {
                    _selected.remove(o.value);
                  }
                });
                widget.onChanged(_selected);
              },
              title: Text(o.label),
            )),
        const SizedBox(height: 4),
        if (widget.maxItems != null)
          Text('${_selected.length}/${widget.maxItems} selected', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FreeTextEditor extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _FreeTextEditor({required this.value, required this.onChanged});

  @override
  State<_FreeTextEditor> createState() => _FreeTextEditorState();
}

class _FreeTextEditorState extends State<_FreeTextEditor> {
  late final TextEditingController _c = TextEditingController(text: widget.value);
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      minLines: 1,
      maxLines: 4,
      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Type your answer…'),
      onChanged: widget.onChanged,
    );
  }
}

class _YesNoEditor extends StatelessWidget {
  final String? value; // 'yes' | 'no'
  final ValueChanged<String?> onChanged;
  const _YesNoEditor({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: value,
      onChanged: onChanged,
      child: Column(children: [
        RadioListTile<String>(value: 'yes', title: const Text('Yes')),
        RadioListTile<String>(value: 'no', title: const Text('No')),
      ]),
    );
  }
}

class _FreeListEditor extends StatefulWidget {
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final int? minItems;
  final int? maxItems;
  const _FreeListEditor({required this.values, required this.onChanged, this.minItems, this.maxItems});

  @override
  State<_FreeListEditor> createState() => _FreeListEditorState();
}

class _FreeListEditorState extends State<_FreeListEditor> {
  late final List<String> _vals = [...widget.values];
  final _controller = TextEditingController();

  void _add() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    if (widget.maxItems != null && _vals.length >= widget.maxItems!) return;
    setState(() { _vals.add(t); });
    widget.onChanged(_vals);
    _controller.clear();
  }

  void _remove(String v) {
    setState(() { _vals.remove(v); });
    widget.onChanged(_vals);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _vals.map((v) => InputChip(
            label: Text(v),
            onDeleted: () => _remove(v),
          )).toList(),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Add item…', border: OutlineInputBorder()))),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add')),
        ]),
        const SizedBox(height: 4),
        if (widget.maxItems != null)
          Text('${_vals.length}/${widget.maxItems} items', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
