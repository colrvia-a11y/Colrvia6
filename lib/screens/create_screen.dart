// lib/screens/create_screen.dart
import 'package:color_canvas/services/journey/journey_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/journey/default_color_story_v1.dart';
import 'package:color_canvas/widgets/journey_timeline.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/services/user_prefs_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'interview_screen.dart';
import 'roller_screen.dart';
import 'visualizer_screen.dart';
import 'learn_screen.dart';
import 'review_contrast_screen.dart';
import 'export_guide_screen.dart';

/// ✨ Create Hub — Guided (orchestrated) + Tools tabs
class CreateHubScreen extends StatefulWidget {
  final String? username;
  final String? heroImageUrl;
  const CreateHubScreen({super.key, this.username, this.heroImageUrl});

  @override
  State<CreateHubScreen> createState() => _CreateHubScreenState();
}

class _CreateHubScreenState extends State<CreateHubScreen> with TickerProviderStateMixin {
  late final TabController _tab;
  final JourneyService _journey = JourneyService.instance;
  bool _loaded = false;
  bool _hasProjects = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Show UI immediately; journey loads in background
    if (mounted) setState(() => _loaded = true);
    try {
      final projects = await ProjectService.myProjectsStream(limit: 1).first;
      _hasProjects = projects.isNotEmpty;
      await _journey.loadForLastProject();
      if (mounted) setState(() {});
    } catch (e) {
      // If journey fails, initialize a safe default state
      final first = _journey.firstStep;
      _journey.state.value = JourneyState(
        journeyId: defaultColorStoryJourneyId,
        projectId: null,
        currentStepId: first.id,
        completedStepIds: const [],
        artifacts: const {},
      );
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final peach = const Color(0xFFF2B897);
    final title = "Create Hub";
    final subtitle = "Design · Learn · Visualize";

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0F12),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
            ],
          ),
          bottom: TabBar(
            controller: _tab,
            tabs: const [Tab(text: "Guided"), Tab(text: "Tools")],
            labelColor: peach,
            unselectedLabelColor: Colors.white70,
            indicatorColor: peach,
          ),
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tab,
                children: [
                  _buildGuided(context),
                  _buildTools(context),
                ],
              ),
      ),
    );
  }

  Widget _buildGuided(BuildContext context) {
    final journey = _journey;
    if (!_hasProjects) {
      return Center(
        child: Semantics(
          label: 'Start your Color Story',
          button: true,
          child: FilledButton(
            onPressed: () async {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) return;
            final pid = await ProjectService.create(ownerId: uid);
            await UserPrefsService.setLastProject(pid, 'create');
            await _journey.loadForProject(pid);
            if (mounted) {
              setState(() {
                _hasProjects = true;
              });
            }
          },
          child: const Text('Start your Color Story'),
        ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress + timeline
          Card(
            elevation: 0,
            color: Colors.white.withValues(alpha: 0.04),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Your Color Story", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  JourneyTimeline(journey: journey),
                  const SizedBox(height: 12),
                  _NextBestAction(journey: journey, onGo: _goToCurrentStep),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Sections with quick actions (read‑only for now)
          _SectionHeader(title: "Design a Palette"),
          _ToolRow(items: [
            _ToolItem(label: "Interview", onTap: () => _open(context, const InterviewScreen())),
            _ToolItem(label: "Roller", onTap: () => _open(context, const RollerScreen())),
          ]),
          _SectionHeader(title: "Refine your Palette"),
          _ToolRow(items: [
            _ToolItem(label: "Learn", onTap: () => _open(context, const LearnScreen())),
          ]),
          _SectionHeader(title: "See your Palette"),
          _ToolRow(items: [
            _ToolItem(label: "Visualizer", onTap: () => _open(context, const VisualizerScreen())),
          ]),
        ],
      ),
    );
  }

  Widget _buildTools(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: "Design a Palette"),
          _ToolRow(items: [
            _ToolItem(label: "Interview", onTap: () => _open(context, const InterviewScreen())),
            _ToolItem(label: "Roller", onTap: () => _open(context, const RollerScreen())),
          ]),
          _SectionHeader(title: "Refine your Palette"),
          _ToolRow(items: [
            _ToolItem(label: "Learn", onTap: () => _open(context, const LearnScreen())),
          ]),
          _SectionHeader(title: "See your Palette"),
          _ToolRow(items: [
            _ToolItem(label: "Visualizer", onTap: () => _open(context, const VisualizerScreen())),
          ]),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _goToCurrentStep() {
    final s = _journey.state.value;
    final current = _journey.stepById(s?.currentStepId) ?? _journey.firstStep;
    switch (current.id) {
      case 'interview.basic':
        _open(context, const InterviewScreen());
        break;
      case 'roller.build':
        _open(context, const RollerScreen());
        break;
      case 'review.contrast':
        _open(context, const ReviewContrastScreen());
        break;
      case 'visualizer.photo':
      case 'visualizer.generate':
        _open(context, const VisualizerScreen());
        break;
      case 'guide.export':
        final pid = s?.projectId;
        if (pid != null) {
          _open(context, ExportGuideScreen(projectId: pid));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No project found')));
        }
        break;
      default:
        // default to Create hub or show dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This step opens from its tool.')));
    }
  }
}

class _NextBestAction extends StatelessWidget {
  final JourneyService journey;
  final VoidCallback onGo;
  const _NextBestAction({required this.journey, required this.onGo});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: journey.state,
      builder: (context, s, _) {
        final step = journey.nextBestStep();
        final label = step?.title ?? 'Start your Color Story';
        return Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            ElevatedButton(onPressed: onGo, child: const Text('Go')),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}

class _ToolRow extends StatelessWidget {
  final List<_ToolItem> items;
  const _ToolRow({required this.items});
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map((it) => GestureDetector(
                onTap: it.onTap,
                child: Container(
                  width: 160,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(it.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _ToolItem {
  final String label;
  final VoidCallback onTap;
  _ToolItem({required this.label, required this.onTap});
}