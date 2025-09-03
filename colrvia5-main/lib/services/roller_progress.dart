// lib/services/roller_progress.dart
import 'package:flutter/foundation.dart';

/// Cross-screen Roller progress (0..1). Use from RollerScreen:
/// RollerProgress.instance.value = 0.35;  // 35% through the flow
class RollerProgress extends ValueNotifier<double> {
  RollerProgress._() : super(0.0);
  static final RollerProgress instance = RollerProgress._();
}
