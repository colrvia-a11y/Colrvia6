import 'package:flutter/material.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/analytics_service.dart';

class ReviewContrastScreen extends StatefulWidget {
  const ReviewContrastScreen({super.key});

  @override
  State<ReviewContrastScreen> createState() => _ReviewContrastScreenState();
}

class _ReviewContrastScreenState extends State<ReviewContrastScreen> {
  final JourneyService journey = JourneyService.instance;
  late final List<String> colors;

  @override
  void initState() {
    super.initState();
    colors = (journey.state.value?.artifacts['palettePreview'] as List?)
            ?.cast<String>() ??
        const <String>[];
    AnalyticsService.instance.logEvent('journey_step_view', {
      'step_id': journey.state.value?.currentStepId ?? 'review.contrast',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contrast Review')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: colors.isNotEmpty
                  ? colors.map((h) => _SwatchRow(hex: h)).toList()
                  : const [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No palette loaded'),
                      ),
                    ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () async {
                await journey.setArtifact('contrastReport', {'checked': true});
                await journey.completeCurrentStep();
                if (context.mounted) {
                  Navigator.of(context).maybePop();
                }
              },
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwatchRow extends StatelessWidget {
  final String hex;
  const _SwatchRow({required this.hex});

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(hex.replaceAll('#', ''), radix: 16) | 0xFF000000);
    return ListTile(
      leading: Semantics(
        label: 'Color swatch $hex',
        child: Container(width: 40, height: 40, color: color),
      ),
      title: Text('Sample text', style: TextStyle(color: _contrast(color))),
    );
  }

  Color _contrast(Color c) =>
      c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
