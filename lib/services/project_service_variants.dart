// lib/services/project_service_variants.dart
// Lightweight persistence shim for palette variant history.
// If your ProjectService already persists history, you can
// replace these helpers with calls into that implementation.

final List<Map<String, dynamic>> _variantHistoryInMemory =
    <Map<String, dynamic>>[];

Future<void> addPaletteHistory(String kind, List<String> palette) async {
  // Append to in-memory log; replace with real persistence as needed.
  _variantHistoryInMemory.add({
    'kind': kind,
    'palette': List<String>.from(palette),
    'ts': DateTime.now().toIso8601String(),
  });
}

List<Map<String, dynamic>> getVariantHistory() =>
    List.unmodifiable(_variantHistoryInMemory);
