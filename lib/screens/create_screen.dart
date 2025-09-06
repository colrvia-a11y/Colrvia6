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
import 'package:color_canvas/services/feature_flags.dart';

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
  final ScrollController _scrollController = ScrollController();
  double _heroHeight = 0;
  static const double _heroMaxHeightFraction = 0.36;
  static const double _heroMinHeight = 74; // just enough for tab bar

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _bootstrap();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxHeight = (MediaQuery.of(context).size.height * _heroMaxHeightFraction).clamp(220.0, MediaQuery.of(context).size.height);
    final minHeight = _heroMinHeight;
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
  // final collapseRange = maxHeight - minHeight; // unused
    double newHeight = (maxHeight - offset).clamp(minHeight, maxHeight);
    if ((newHeight - _heroHeight).abs() > 1) {
      setState(() {
        _heroHeight = newHeight;
      });
    }
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
    final title = "Create Hub";
    final subtitle = "Design · Learn · Visualize";

    final maxHeroHeight = (MediaQuery.of(context).size.height * _heroMaxHeightFraction).clamp(220.0, MediaQuery.of(context).size.height);
    if (_heroHeight == 0) _heroHeight = maxHeroHeight;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: _heroHeight,
                child: _topHero(title: title, subtitle: subtitle, collapsed: _heroHeight <= _heroMinHeight + 2),
              ),
              Expanded(
                child: Column(
                  children: [
                    // When collapsed, show a sticky copy of the tab bar above the content
                    if (_heroHeight <= _heroMinHeight + 2)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withAlpha(61),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _buildTabBar(),
                        ),
                      ),
                    Expanded(
                      child: !_loaded
                          ? const Center(child: CircularProgressIndicator())
                          : NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n is ScrollUpdateNotification) _onScroll();
                                return false;
                              },
                              child: TabBarView(
                                controller: _tab,
                                children: [
                                  _buildGuided(context, controller: _scrollController),
                                  _buildTools(context, controller: _scrollController),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top hero header with curved bottom and integrated TabBar (matches Search UI)
  Widget _topHero({required String title, required String subtitle, bool collapsed = false}) {
    final theme = Theme.of(context);
  // final size = MediaQuery.of(context).size; // unused
    final bgImage = widget.heroImageUrl ??
        'https://images.pexels.com/photos/1571460/pexels-photo-1571460.jpeg?auto=compress&cs=tinysrgb&w=1200&q=80';
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(bgImage),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Overlay gradient for readability
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface.withOpacity(0.18),
                  Colors.transparent,
                  Colors.black.withOpacity(0.22),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
          // Centered title/subtitle (hide when collapsed)
          if (!collapsed)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ) ?? const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ) ?? const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Tab container near bottom (inside hero when expanded)
          if (!collapsed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withAlpha(61),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _buildTabBar(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    return TabBar(
      controller: _tab,
      isScrollable: false,
      dividerColor: Colors.transparent,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(vertical: 10),
      indicatorPadding: EdgeInsets.zero,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: ShapeDecoration(
        color: theme.colorScheme.onSurface.withAlpha(72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      labelColor: theme.colorScheme.onSurface,
      unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(170),
      tabs: const [Tab(text: 'AI Guided'), Tab(text: 'Design Tools')],
    );
  }

  Widget _buildGuided(BuildContext context, {ScrollController? controller}) {
  final journey = _journey;
  final theme = Theme.of(context);
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
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress + timeline
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your Color Story",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
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
            _ToolItem(label: "Interview", onTap: () => Navigator.of(context).pushNamed('/interview/home')),
            if (FeatureFlags.instance.isEnabled(FeatureFlags.voiceInterview))
              _ToolItem(label: "Talk to Via", onTap: () => Navigator.of(context).pushNamed('/interview/voice-setup')),
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

  Widget _buildTools(BuildContext context, {ScrollController? controller}) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: "Design a Palette"),
          _ToolRow(items: [
            _ToolItem(label: "Interview", onTap: () => Navigator.of(context).pushNamed('/interview/home')),
            if (FeatureFlags.instance.isEnabled(FeatureFlags.voiceInterview))
              _ToolItem(label: "Talk to Via", onTap: () => Navigator.of(context).pushNamed('/interview/voice-setup')),
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
        Navigator.of(context).pushNamed('/interview/home');
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
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
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
  child: Text(
    title,
    style: Theme.of(context)
    .textTheme
    .titleSmall
    ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
  ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  final List<_ToolItem> items;
  const _ToolRow({required this.items});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline.withAlpha(26)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      it.label,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
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

