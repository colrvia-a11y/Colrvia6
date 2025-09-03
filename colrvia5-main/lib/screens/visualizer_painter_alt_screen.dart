// lib/screens/visualizer_painter_alt_screen.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/rendering.dart';

import 'package:color_canvas/models/palette_models.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/widgets/photo_picker_inline.dart';

class VisualizerPainterAltScreen extends StatefulWidget {
  const VisualizerPainterAltScreen({super.key});

  @override
  State<VisualizerPainterAltScreen> createState() => _VisualizerPainterAltScreenState();
}

class _VisualizerPainterAltScreenState extends State<VisualizerPainterAltScreen> {
  final _boundaryKey = GlobalKey();

  Palette? _pal;
  List<String> _photos = const [];
  int _index = 0;

  String _role = 'anchor'; // anchor | secondary | accent
  double _opacity = 0.6;
  double _brush = 28;

  final _strokesByPhoto = <int, List<_Stroke>>{};
  _Stroke? _current;
  Offset? _lastPt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final art = JourneyService.instance.state.value?.artifacts ?? {};
    final pjson = (art['palette'] as Map?)?.cast<String, dynamic>();
    Palette? pal; if (pjson != null) pal = Palette.fromJson(pjson);
    final photos = (art['answers']?['photos'] as List?)?.cast<String>() ?? const [];
    setState(() { _pal = pal; _photos = photos; });
  }

  Color _parse(String hex) {
    String h = hex.replaceAll('#', '');
    if (h.length == 3) h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
    return Color(int.parse('FF$h', radix: 16));
  }

  Color _roleColor() {
    final pal = _pal; if (pal == null) return Colors.blueGrey;
    switch (_role) {
      case 'anchor': return _parse(pal.roles.anchor.code);
      case 'secondary': return _parse(pal.roles.secondary.code);
      case 'accent': return _parse(pal.roles.accent.code);
      default: return Colors.blueGrey;
    }
  }

  List<_Stroke> get _strokes => _strokesByPhoto[_index] ??= <_Stroke>[];

  void _start(Offset p) {
    final path = Path()..moveTo(p.dx, p.dy);
    _current = _Stroke(path: path, role: _role, opacity: _opacity, width: _brush);
    _strokes.add(_current!);
    _lastPt = p;
    setState(() {});
  }

  void _drag(Offset p) {
    final last = _lastPt; if (last == null) return;
    final dx = p.dx - last.dx, dy = p.dy - last.dy;
    final dist2 = dx*dx + dy*dy;
    final minDist = (_brush * 0.35);
    if (dist2 < minDist * minDist) return;
    _current?.path.lineTo(p.dx, p.dy);
    _lastPt = p;
    setState(() {});
  }

  void _end() { _current = null; _lastPt = null; }

  void _undo() { final s = _strokes; if (s.isNotEmpty) setState(() => s.removeLast()); }
  void _clear() { setState(() => _strokesByPhoto[_index] = <_Stroke>[]); }

  Future<void> _export() async {
    try {
      final rb = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (rb == null) return;
      final img = await rb.toImage(pixelRatio: 3.0);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/colrvia-overlay-${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(bytes);
      // ignore: use_build_context_synchronously
      await Share.shareXFiles([XFile(f.path)], text: 'Colrvia Paint Overlay');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paint Overlay (Alt Visualizer)')),
      body: _pal == null
          ? const Center(child: Text('Generate a palette first.'))
          : (_photos.isEmpty ? _emptyState() : Column(children: [
              _paletteHeader(),
              Expanded(child: _canvas()),
              _toolbar(),
            ])),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add a room photo to start', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        PhotoPickerInline(
          value: _photos,
          onChanged: (next) async {
            setState(() => _photos = next);
            final answers = JourneyService.instance.state.value?.artifacts['answers'] as Map<String, dynamic>? ?? {};
            answers['photos'] = next;
            await JourneyService.instance.setArtifact('answers', answers);
          },
        ),
      ]),
    );
  }

  Widget _paletteHeader() {
    final pal = _pal!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16,8,16,8),
      child: Row(children: [
        _rolePill('anchor', pal.roles.anchor.name, pal.roles.anchor.code, 'Main walls'),
        const SizedBox(width: 8),
        _rolePill('secondary', pal.roles.secondary.name, pal.roles.secondary.code, 'Trim & cabinets'),
        const SizedBox(width: 8),
        _rolePill('accent', pal.roles.accent.name, pal.roles.accent.code, 'Door/Built-ins'),
        const Spacer(),
        IconButton(onPressed: _undo, icon: const Icon(Icons.undo), tooltip: 'Undo'),
        IconButton(onPressed: _clear, icon: const Icon(Icons.delete_sweep_outlined), tooltip: 'Clear'),
        IconButton(onPressed: _export, icon: const Icon(Icons.ios_share), tooltip: 'Share'),
      ]),
    );
  }

  Widget _rolePill(String role, String name, String hex, String semantics) {
    final selected = _role == role;
    return Semantics(
      button: true,
      label: 'Select $role color. $semantics',
      child: InkWell(
        onTap: () => setState(() => _role = role),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.black87 : Colors.black12,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: _parse(hex), shape: BoxShape.circle, border: Border.all(color: Colors.black26))),
            const SizedBox(width: 6),
            Text(name, style: TextStyle(color: selected ? Colors.white : Colors.black87)),
          ]),
        ),
      ),
    );
  }

  Widget _canvas() {
    final imageUrl = _photos[_index];
    return RepaintBoundary(
      key: _boundaryKey,
      child: Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 0.5, maxScale: 4.0,
            child: Stack(children: [
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) => _start(d.localPosition),
                  onPanUpdate: (d) => _drag(d.localPosition),
                  onPanEnd: (_) => _end(),
                  child: CustomPaint(painter: _Painter(strokes: _strokes), child: const SizedBox.expand()),
                ),
              ),
            ]),
          ),
        ),
        if (_photos.length > 1)
          Positioned(
            bottom: 12, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(color: Colors.white, onPressed: () => setState(() => _index = (_index - 1 + _photos.length) % _photos.length), icon: const Icon(Icons.chevron_left)),
                  Text('${_index + 1}/${_photos.length}', style: const TextStyle(color: Colors.white)),
                  IconButton(color: Colors.white, onPressed: () => setState(() => _index = (_index + 1) % _photos.length), icon: const Icon(Icons.chevron_right)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _toolbar() {
    final color = _roleColor();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Column(children: [
          Row(children: [
            const Text('Brush'),
            Expanded(child: Slider(value: _brush, min: 8, max: 72, onChanged: (v) => setState(() => _brush = v))),
            Semantics(label: 'Brush color sample', child: Container(width: 28, height: 28, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: const [BoxShadow(blurRadius: 2, spreadRadius: 0.5, color: Colors.black26)]))),
          ]),
          Row(children: [
            const Text('Opacity'),
            Expanded(child: Slider(value: _opacity, min: 0.15, max: 0.95, onChanged: (v) => setState(() => _opacity = v))),
            Text('${(_opacity * 100).round()}%'),
          ]),
        ]),
      ),
    );
  }
}

class _Stroke {
  final Path path;
  final String role; // anchor/secondary/accent
  final double opacity;
  final double width;
  _Stroke({required this.path, required this.role, required this.opacity, required this.width});
}

class _Painter extends CustomPainter {
  final List<_Stroke> strokes;
  _Painter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = _roleColor(s.role).withOpacity(s.opacity)
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.multiply; // keep texture
      canvas.drawPath(s.path, paint);
    }
  }

  static Color _roleColor(String role) {
    switch (role) {
      case 'anchor': return const Color(0xFFB0BEC5);
      case 'secondary': return const Color(0xFFE0E0E0);
      case 'accent': return const Color(0xFF90CAF9);
      default: return const Color(0xFFB0BEC5);
    }
  }

  @override
  bool shouldRepaint(covariant _Painter oldDelegate) => oldDelegate.strokes != strokes;
}
