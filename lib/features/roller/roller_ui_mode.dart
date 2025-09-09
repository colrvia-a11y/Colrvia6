import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RollerMode { explore, edit }

final rollerModeProvider =
    StateProvider<RollerMode>((ref) => RollerMode.explore);
