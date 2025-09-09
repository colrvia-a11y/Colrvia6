import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/features/roller/widgets/roller_feed.dart';

class RollerScreen extends ConsumerWidget {
  const RollerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: RollerFeed(),
    );
  }
}
