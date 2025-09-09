import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Suggestion {
  final String label;
  final String? query;
  final String? colorFamily;
  final String? undertone;
  final String? temperature;
  final RangeValues? lrv;

  const Suggestion({
    required this.label,
    this.query,
    this.colorFamily,
    this.undertone,
    this.temperature,
    this.lrv,
  });
}

class SuggestionChips extends StatelessWidget {
  final List<Suggestion> suggestions;
  final void Function(Suggestion s) onTap;

  const SuggestionChips(
      {super.key, required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 2),
        itemBuilder: (_, i) {
          final s = suggestions[i];
          return InputChip(
            label: Text(s.label),
            onPressed: () {
              HapticFeedback.selectionClick();
              onTap(s);
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.7),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: suggestions.length,
      ),
    );
  }
}
