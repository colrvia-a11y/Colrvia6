// lib/widgets/journey_timeline.dart
import 'package:flutter/material.dart';
import 'package:color_canvas/services/journey/journey_service.dart';
import '../theme.dart';

class JourneyTimeline extends StatelessWidget {
  final JourneyService journey;
  const JourneyTimeline({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: journey.state,
      builder: (context, s, _) {
        final steps = journey.steps;
        final Set<String> done = s?.completedStepIds.toSet() ?? {};
        final currentId = s?.currentStepId;
        return Wrap(
          spacing: AppDims.gap,
          runSpacing: AppDims.gap,
          children: [
            for (final step in steps)
              _StepPill(
                label: step.title,
                isCurrent: step.id == currentId,
                isDone: done.contains(step.id),
              )
          ],
        );
      },
    );
  }
}

class _StepPill extends StatelessWidget {
  final String label;
  final bool isCurrent;
  final bool isDone;
  const _StepPill(
      {required this.label, required this.isCurrent, required this.isDone});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final peach = colorScheme.secondary;
    final bg = isCurrent
        ? peach.withAlpha((255 * 0.15).round())
        : Colors.white.withAlpha((255 * 0.06).round());
    final border = isDone
        ? peach
        : (isCurrent ? peach.withAlpha((255 * 0.7).round()) : Colors.white24);
    final fg = isDone
        ? peach
        : (isCurrent ? peach : Colors.white.withAlpha((255 * 0.9).round()));

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDims.gap * 2, vertical: AppDims.gap),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              isDone
                  ? Icons.check_circle
                  : (isCurrent
                      ? Icons.timelapse
                      : Icons.radio_button_unchecked),
              size: 16,
              color: fg),
          const SizedBox(width: 8),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
