import 'package:flutter/material.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/utils/color_utils.dart';
import '../services/analytics_service.dart';

class CompareColorsScreen extends StatefulWidget {
  final List<String> paletteColorIds;
  const CompareColorsScreen({super.key, required this.paletteColorIds});

  @override
  State<CompareColorsScreen> createState() => _CompareColorsScreenState();
}

class _CompareColorsScreenState extends State<CompareColorsScreen> {
  late Future<List<Paint>> _paintsFuture;

  @override
  void initState() {
    super.initState();
    _paintsFuture =
        FirebaseService.getPaintsByIds(widget.paletteColorIds.take(4).toList());
    AnalyticsService.instance.compareOpened(widget.paletteColorIds.length);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Paint>>(
      future: _paintsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Compare Colors')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final paints = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: const Text('Compare Colors')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: paints
                    .map((p) => Expanded(child: _SwatchCard(paint: p)))
                    .toList(),
              ),
              const SizedBox(height: 16),
              _ContrastTable(paints: paints),
            ],
          ),
        );
      },
    );
  }
}

class _SwatchCard extends StatelessWidget {
  final Paint paint;
  const _SwatchCard({required this.paint});

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Container(color: color)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(paint.name, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text('LRV ${paint.computedLrv.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContrastTable extends StatelessWidget {
  final List<Paint> paints;
  const _ContrastTable({required this.paints});

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.black12),
      children: [
        TableRow(children: [
          const SizedBox(),
          for (final p in paints)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ]),
        for (final a in paints)
          TableRow(children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(a.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final b in paints)
              Padding(
                padding: const EdgeInsets.all(8),
                child:
                    a.id == b.id ? const Text('—') : _ContrastCell(a: a, b: b),
              ),
          ]),
      ],
    );
  }
}

class _ContrastCell extends StatelessWidget {
  final Paint a;
  final Paint b;
  const _ContrastCell({required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    final colorA = ColorUtils.getPaintColor(a.hex);
    final colorB = ColorUtils.getPaintColor(b.hex);
    final contrast = contrastRatio(colorA, colorB);
    final lrvDiff = (a.computedLrv - b.computedLrv).abs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ΔLRV ${lrvDiff.toStringAsFixed(1)}',
            style: Theme.of(context).textTheme.bodySmall),
        Text('${contrast.toStringAsFixed(2)}:1',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
