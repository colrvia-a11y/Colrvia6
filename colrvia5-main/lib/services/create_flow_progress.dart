import 'package:flutter/foundation.dart';

/// Tracks progress for the Create hub (0..1), with a source tag so
/// Interview/Roller/etc. can update without stomping each other accidentally.
/// Last-writer-wins; the nav bar just listens to `value`.
class CreateFlowProgress extends ValueNotifier<double> {
  CreateFlowProgress._() : super(0.0);
  static final CreateFlowProgress instance = CreateFlowProgress._();

  String? _source; // 'interview' | 'roller' | 'learn' | etc.
  String? get source => _source;

  /// Set progress for a specific source (0..1). Clamp and notify.
  void set(String source, double v) {
    _source = source;
    value = v.clamp(0.0, 1.0);
  }

  /// Clear if the same source is leaving/end-of-flow.
  void clear(String source) {
    if (_source == source) {
      _source = null;
      value = 0.0;
    }
  }

  /// Force clear (e.g., leaving Create entirely).
  void reset() {
    _source = null;
    value = 0.0;
  }
}
