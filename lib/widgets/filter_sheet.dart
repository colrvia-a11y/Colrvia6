// lib/widgets/filter_sheet.dart
import 'package:flutter/material.dart';
import '../models/color_filters.dart';

class FilterSheet extends StatefulWidget {
  final ColorFilters initial;
  final void Function(ColorFilters) onApply;

  const FilterSheet({super.key, required this.initial, required this.onApply});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ColorFilters filters;

  static const families = [
    'Red',
    'Orange',
    'Yellow',
    'Green',
    'Blue',
    'Purple',
    'Neutral',
    'White',
    'Gray',
    'Brown',
    'Black'
  ];
  static const undertones = [
    'green',
    'blue',
    'violet',
    'yellow',
    'red',
    'neutral'
  ];
  static const temps = ['Warm', 'Cool', 'Neutral'];
  static const brands = [
    'Sherwin-Williams',
    'Benjamin Moore',
    'Behr'
  ]; // extend at runtime later

  @override
  void initState() {
    super.initState();
    filters = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Filters',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() => filters = filters.clear());
                  },
                  child: const Text('Clear all'),
                )
              ],
            ),
            const SizedBox(height: 12),
            _chipSection(
                'Color family',
                families,
                filters.colorFamily,
                (v) =>
                    setState(() => filters = filters.copyWith(colorFamily: v))),
            _chipSection(
                'Undertone',
                undertones,
                filters.undertone,
                (v) =>
                    setState(() => filters = filters.copyWith(undertone: v))),
            _chipSection(
                'Temperature',
                temps,
                filters.temperature,
                (v) =>
                    setState(() => filters = filters.copyWith(temperature: v))),
            const SizedBox(height: 12),
            Text('LRV range', style: theme.textTheme.titleMedium),
            RangeSlider(
              values: filters.lrvRange ?? const RangeValues(0, 100),
              min: 0,
              max: 100,
              divisions: 20,
              labels: RangeLabels(
                (filters.lrvRange?.start ?? 0).round().toString(),
                (filters.lrvRange?.end ?? 100).round().toString(),
              ),
              onChanged: (val) =>
                  setState(() => filters = filters.copyWith(lrvRange: val)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: brands
                  .map((b) => ChoiceChip(
                        label: Text(b),
                        selected: filters.brandName == b,
                        onSelected: (sel) => setState(() => filters =
                            filters.copyWith(brandName: sel ? b : null)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onApply(filters);
                },
                icon: const Icon(Icons.check),
                label: const Text('Apply filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipSection(String title, List<String> options, String? current,
      void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map((opt) => ChoiceChip(
                    label: Text(opt),
                    selected: current == opt,
                    onSelected: (sel) => onChanged(sel ? opt : null),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
