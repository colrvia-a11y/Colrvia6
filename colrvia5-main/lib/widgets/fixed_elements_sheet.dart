// lib/widgets/fixed_elements_sheet.dart
import 'package:flutter/material.dart';
import '../models/fixed_elements.dart';
import '../services/fixed_element_service.dart';

/// Bottom sheet for managing fixed elements in a project.
class FixedElementsSheet extends StatefulWidget {
  final String projectId;
  final List<FixedElement> elements;
  const FixedElementsSheet({super.key, required this.projectId, required this.elements});

  @override
  State<FixedElementsSheet> createState() => _FixedElementsSheetState();
}

class _FixedElementsSheetState extends State<FixedElementsSheet> {
  late List<FixedElement> _elements;

  static const _undertones = ['warm', 'cool', 'neutral'];
  static const _types = ['floor', 'counter', 'tile', 'other'];

  @override
  void initState() {
    super.initState();
    _elements = widget.elements.map((e) => e).toList();
  }

  void _addElement() {
    setState(() {
      _elements.add(FixedElement(
          id: UniqueKey().toString(),
          name: '',
          type: 'other',
          undertone: 'neutral'));
    });
  }

  Future<void> _save() async {
    await FixedElementService().saveAll(widget.projectId, _elements);
    if (mounted) {
      Navigator.of(context).pop(_elements);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fixed Elements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _elements.length,
              itemBuilder: (context, i) {
                final e = _elements[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          decoration: const InputDecoration(labelText: 'Name'),
                          controller: TextEditingController(text: e.name),
                          onChanged: (v) => _elements[i] = e.copyWith(name: v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButton<String>(
                                value: e.type,
                                isExpanded: true,
                                items: _types
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (v) => setState(() => _elements[i] = e.copyWith(type: v)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: e.undertone,
                                isExpanded: true,
                                items: _undertones
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (v) => setState(() => _elements[i] = e.copyWith(undertone: v)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setState(() => _elements.removeAt(i)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _addElement,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
