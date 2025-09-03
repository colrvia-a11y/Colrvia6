// lib/widgets/interview_widgets.dart
import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final Widget child;
  final bool isUser;
  const ChatBubble({super.key, required this.child, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final bg = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceVariant;
    final fg = Theme.of(context).colorScheme.onSurface;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: fg, fontSize: 15),
          child: child,
        ),
      ),
    );
  }
}

class OptionChips extends StatelessWidget {
  final List<String> options; // human labels
  final void Function(String value) onTap;
  const OptionChips({super.key, required this.options, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((o) => ActionChip(
                label: Text(o),
                onPressed: () => onTap(o),
              ))
          .toList(),
    );
  }
}

class MultiSelectChips extends StatefulWidget {
  final List<String> options;
  final List<String> initial;
  final int? minItems;
  final int? maxItems;
  final void Function(List<String>) onChanged;
  const MultiSelectChips({
    super.key,
    required this.options,
    this.initial = const [],
    this.minItems,
    this.maxItems,
    required this.onChanged,
  });

  @override
  State<MultiSelectChips> createState() => _MultiSelectChipsState();
}

class _MultiSelectChipsState extends State<MultiSelectChips> {
  late List<String> selected = [...widget.initial];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.options.map((o) {
            final picked = selected.contains(o);
            return FilterChip(
              label: Text(o),
              selected: picked,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    if (widget.maxItems == null ||
                        selected.length < widget.maxItems!) {
                      selected.add(o);
                    }
                  } else {
                    selected.remove(o);
                  }
                });
                widget.onChanged(selected);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (widget.maxItems != null)
          Text('${selected.length}/${widget.maxItems} selected',
              style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
