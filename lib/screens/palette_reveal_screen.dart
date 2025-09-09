import 'package:flutter/material.dart';
import 'package:color_canvas/models/palette_models.dart';
import 'package:color_canvas/services/contrast_utils.dart';
import 'package:color_canvas/services/palette_suggestions_service.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/screens/visualizer_painter_alt_screen.dart';
import '../theme.dart';

class PaletteRevealScreen extends StatefulWidget {
  final Map<String, dynamic>? paletteJson; // optional direct payload
  const PaletteRevealScreen({super.key, this.paletteJson});

  @override
  State<PaletteRevealScreen> createState() => _PaletteRevealScreenState();
}

class _PaletteRevealScreenState extends State<PaletteRevealScreen> {
  Palette? _palette;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<PaintColor> _accentAlternates = [];
  PaintColor? _accentPreview; // transient selection

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      Map<String, dynamic>? pjson = widget.paletteJson;
      final art = JourneyService.instance.state.value?.artifacts;
      pjson ??= (art?['palette'] as Map?)?.cast<String, dynamic>();
      pjson ??= await _tryFetchById(art?['paletteId'] as String?);

      if (pjson == null) throw Exception('No palette found in artifacts.');
      final pal = Palette.fromJson(pjson);
      setState(() => _palette = pal);
      await _loadAlternates();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _tryFetchById(String? id) async {
    if (id == null) return null;
    // TODO: hook up PaletteService.getById(id). For now, return null.
    return null;
  }

  Future<void> _loadAlternates() async {
    if (_palette == null) return;
    final answers = JourneyService.instance.state.value?.artifacts['answers']
        as Map<String, dynamic>?;
    final alts = await PaletteSuggestionsService.instance
        .suggestAccentAlternatives(base: _palette!, answers: answers);
    setState(() => _accentAlternates = alts);
  }

  Future<void> _applyAccent(PaintColor c) async {
    if (_palette == null) return;
    setState(() {
      _accentPreview = c;
      _saving = true;
    });
    final updated =
        _palette!.copyWith(roles: _palette!.roles.copyWith(accent: c));
    await JourneyService.instance.setArtifact('palette', updated.toJson());
    setState(() {
      _palette = updated;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your palette')),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (_, i) => Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            height: i == 3 ? 120 : 72,
            decoration: BoxDecoration(
              color: Colors.black12.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Palette')),
          body: Center(child: Text(_error!)));
    }
    final pal = _palette!;

    final anchor = pal.roles.anchor;
    final secondary = pal.roles.secondary;
    final accent = _accentPreview ?? pal.roles.accent;

    final c1 = assessContrast(anchor.code, secondary.code); // wall vs trim
    final c2 = assessContrast(anchor.code, accent.code); // wall vs accent

    return Scaffold(
      appBar: AppBar(title: const Text('Your palette')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(pal.brand, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            _roleRow(context, 'Anchor (walls)', anchor),
            _roleRow(context, 'Secondary (trim/cabinets)', secondary),
            _roleRow(context, 'Accent (door/built-ins)', accent),
            const SizedBox(height: 12),
            _contrastCard('Walls vs Trim', anchor.code, secondary.code, c1),
            _contrastCard('Walls vs Accent', anchor.code, accent.code, c2),
            const SizedBox(height: 12),
            _rationale(pal),
            const SizedBox(height: 16),
            _swapAccentSection(context, pal, accent),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _goVisualizer,
                  icon: const Icon(Icons.photo_size_select_large_outlined),
                  label: const Text('See it on your walls'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const VisualizerPainterAltScreen()),
                    );
                  },
                  icon: const Icon(Icons.brush_outlined),
                  label: const Text('Try Paint Overlay (Alt Visualizer)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleRow(BuildContext context, String label, PaintColor c) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(
            '${c.name} • ${c.code}${c.lrv != null ? ' • LRV ${c.lrv!.toStringAsFixed(0)}' : ''}${c.undertone != null ? ' • ${c.undertone}' : ''}'),
        trailing: Container(
          width: 56,
          height: 28,
          decoration: BoxDecoration(
            color: _parseColor(c.code),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black12),
          ),
        ),
      ),
    );
  }

  Widget _contrastCard(
      String title, String aHex, String bHex, ContrastReport r) {
    final a = _parseColor(aHex), b = _parseColor(bHex);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDims.gap * 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              _badge(r.grade),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _swatch(a),
              const SizedBox(width: 8),
              _swatch(b),
              const SizedBox(width: 12),
              Text('${r.ratio.toStringAsFixed(1)}:1  •  ${r.hint}'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _rationale(Palette p) {
    final r = p.rationale ?? const {};
    if (r.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDims.gap * 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why this works',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (r['lighting'] != null) Text('Lighting: ${r['lighting']}'),
            if (r['mood'] != null) Text('Mood: ${r['mood']}'),
            if (r['floors'] != null) Text('Floors: ${r['floors']}'),
          ],
        ),
      ),
    );
  }

  Widget _swapAccentSection(
      BuildContext context, Palette pal, PaintColor current) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDims.gap * 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Try a different accent',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (_saving)
                const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _accentChip(current, label: 'Current', onTap: null),
              for (final c in _accentAlternates)
                _accentChip(c, onTap: () => _applyAccent(c)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _accentChip(PaintColor c, {VoidCallback? onTap, String? label}) {
    return ActionChip(
      avatar: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: _parseColor(c.code),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12),
        ),
      ),
      label: Text(label ?? c.name),
      onPressed: onTap,
    );
  }

  Widget _badge(String grade) {
    Color bg;
    Color fg;
    switch (grade) {
      case 'High':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case 'OK':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case 'Soft':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      default:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(grade, style: TextStyle(color: fg)),
    );
  }

  Widget _swatch(Color c) => Container(
        width: 32,
        height: 20,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black12),
        ),
      );

  Color _parseColor(String hex) {
    String h = hex.replaceAll('#', '');
    if (h.length == 3) {
      h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
    }
    return Color(int.parse('FF$h', radix: 16));
  }

  void _goVisualizer() {
    // Let your Guided flow route to the Visualizer step. Here we just pop.
    Navigator.of(context).maybePop();
  }
}
