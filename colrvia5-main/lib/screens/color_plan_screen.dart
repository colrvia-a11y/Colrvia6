import 'package:flutter/material.dart';
import '../models/color_plan.dart';
import '../services/color_plan_service.dart';
import '../services/analytics_service.dart';
import '../services/user_prefs_service.dart';
import '../services/journey/journey_service.dart';

typedef SetLastProjectFn = Future<void> Function(String projectId, String screen);

@visibleForTesting
SetLastProjectFn setLastProjectFn = UserPrefsService.setLastProject;

class ColorPlanScreen extends StatefulWidget {
  final String projectId;
  final List<String>? paletteColorIds;
  // Optional compatibility params used by other screens
  final String? remixStoryId;
  final String? paletteId;
  final ColorPlanService? svc;

  const ColorPlanScreen({
    super.key,
    required this.projectId,
    this.paletteColorIds,
    this.remixStoryId,
    this.paletteId,
    this.svc,
  });

  @override
  State<ColorPlanScreen> createState() => _ColorPlanScreenState();
}

class _ColorPlanScreenState extends State<ColorPlanScreen> {
  late final ColorPlanService _svc;
  ColorPlan? _plan;
  bool _loading = false;
  String? _error;
  bool _showRetry = false;

  @override
  void initState() {
    super.initState();
    _svc = widget.svc ?? ColorPlanService();
    AnalyticsService.instance.log('journey_step_view', {
      'step_id': JourneyService.instance.state.value?.currentStepId ?? 'plan.create',
    });
    setLastProjectFn(widget.projectId, 'plan');
    _generate();
  }

  Future<void> _generate() async {
    if (widget.paletteColorIds == null || widget.paletteColorIds!.isEmpty) {
      setState(() => _error = 'No palette selected');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plan = await _svc.createPlan(
        projectId: widget.projectId,
        paletteColorIds: widget.paletteColorIds!,
        context: {'lightingProfile': 'auto'},
      );

      await JourneyService.instance
          .completeCurrentStep(artifacts: {'planId': plan.id});

      // Telemetry - record plan generation details using structured params
      await AnalyticsService.instance.logEvent('plan_generated', {
        'count': plan.paletteColorIds.length,
        'has_map': plan.placementMap.isNotEmpty,
        'has_playbook': plan.roomPlaybook.isNotEmpty,
      });

      setState(() {
        _plan = plan;
        _showRetry = plan.isFallback;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
  if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
  if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Color Plan')), body: Center(child: Text(_error!)));
  if (_plan == null) return Scaffold(appBar: AppBar(title: const Text('Color Plan')), body: const Center(child: Text('No plan generated')));

    final plan = _plan!;
    final banner = _showRetry
        ? MaterialBanner(
            content: const Text('Showing quick plan. Tap retry for full plan.'),
            actions: [
              TextButton(
                  onPressed: () {
                    setState(() => _showRetry = false);
                    _generate();
                  },
                  child: const Text('Retry')),
            ],
          )
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(plan.name)),
      body: Column(
        children: [
          if (banner != null) banner,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
          Text(plan.vibe, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _Section(
            title: 'Placement Map',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.placementMap.map((p) => Text('${p.area}: ${p.colorId}')).toList(),
            ),
          ),
          _Section(
            title: 'Cohesion Tips',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.cohesionTips.map((t) => Text('• $t')).toList(),
            ),
          ),
          _Section(
            title: 'Accent Rules',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.accentRules.map((a) => Text('• ${a.context}: ${a.guidance}')).toList(),
            ),
          ),
          _Section(
            title: 'Do / Don\'t',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.doDont.map((d) => Text('✓ ${d.doText}   ✗ ${d.dontText}')).toList(),
            ),
          ),
          _Section(
            title: 'Sample Sequence',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.sampleSequence.map((s) => Text('• $s')).toList(),
            ),
          ),
          _Section(
            title: 'Room-by-Room Playbook',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  plan.roomPlaybook.map((r) => Text('${r.roomType}: ${r.notes}')).toList(),
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
