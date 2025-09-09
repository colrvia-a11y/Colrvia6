// lib/screens/create_screen.dart
import 'package:color_canvas/services/journey/journey_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

import 'package:color_canvas/services/journey/journey_service.dart';
import 'package:color_canvas/services/journey/default_color_story_v1.dart';
import 'package:color_canvas/widgets/journey_timeline.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/services/user_prefs_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class _CreateHubScreenState extends State<CreateHubScreen>
    with TickerProviderStateMixin {
  /// New Design tab content
  Widget _buildDesign(BuildContext context, {ScrollController? controller}) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionIntro(
              title: 'Design',
              subtitle: 'Pick your path. Two beautiful ways to start.'),
          const SizedBox(height: 12),
          _FeatureGrid(
            cards: [
              _FeatureCardData(
                semanticLabel: 'Start with AI Palette Builder',
                title: 'AI Palette Builder',
                subtitle:
                    'Answer a few quick questions. We craft a cohesive system for you.',
                actionLabel: 'Start with AI',
                icon: Icons.auto_awesome,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.85),
                    theme.colorScheme.tertiary.withValues(alpha: 0.85),
                  ],
                ),
                onTap: () => Navigator.of(context).pushNamed('/interview/home'),
              ),
              _FeatureCardData(
                semanticLabel: 'Open Roller Designer',
                title: 'Roller Designer',
                subtitle:
                    'Play with tone, contrast, and harmony using tactile controls.',
                actionLabel: 'Open Roller',
                icon: Icons.tune_rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.85),
                    theme.colorScheme.primary.withValues(alpha: 0.70),
                  ],
                ),
                onTap: () => _open(context, const RollerScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  late TabController _tab;
  static const int _tabCount = 3;
  final JourneyService _journey = JourneyService.instance;
  bool _loaded = false;
  bool _hasProjects = true;
  // One ScrollController per tab to avoid attaching a single controller to multiple scroll views
  late final List<ScrollController> _scrollControllers;
  // Accumulator for wheel/trackpad scrolling over the TabBar
  double _tabWheelAccum = 0.0;
  double _heroHeight = 0;
  static const double _heroMaxHeightFraction = 0.36;
  static const double _heroMinHeight = 74; // just enough for tab bar

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabCount, vsync: this, initialIndex: 0);
    // create per-tab scroll controllers
    _scrollControllers = List.generate(_tabCount, (i) => ScrollController());
    _bootstrap();
  }

  @override
  void dispose() {
    for (final c in _scrollControllers) {
      c.dispose();
    }
    _tab.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Use the active tab's scroll controller to compute hero collapse
    final activeIndex = (_tab.index).clamp(0, _tabCount - 1);
    final controller = _scrollControllers[activeIndex];
    final maxHeight =
        (MediaQuery.of(context).size.height * _heroMaxHeightFraction)
            .clamp(220.0, MediaQuery.of(context).size.height);
    final minHeight = _heroMinHeight;
    final offset = controller.hasClients ? controller.offset : 0.0;
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

    final maxHeroHeight =
        (MediaQuery.of(context).size.height * _heroMaxHeightFraction)
            .clamp(220.0, MediaQuery.of(context).size.height);
    if (_heroHeight == 0) _heroHeight = maxHeroHeight;
    // Compute hero text opacity: fade out faster and complete before full collapse.
    // collapseProgress: 0.0 at fully expanded, 1.0 at fully collapsed
    final double collapseProgress =
        ((maxHeroHeight - _heroHeight) / (maxHeroHeight - _heroMinHeight))
            .clamp(0.0, 1.0)
            .toDouble();
    // Finish fade by ~40% collapsed so text is gone before the tab bar overlaps it
    const double fadeEndAt = 0.4; // more aggressive early fade
    final double fadePhase = (collapseProgress / fadeEndAt).clamp(0.0, 1.0);
    // Use easeOut so opacity drops quickly at the start of scroll
    final double heroTextOpacity =
        1.0 - Curves.easeOutQuint.transform(fadePhase);
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
                child: _topHero(
                  title: title,
                  subtitle: subtitle,
                  collapsed: _heroHeight <= _heroMinHeight + 2,
                  textOpacity: heroTextOpacity,
                ),
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
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withAlpha(61),
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
                                  _buildDesign(context,
                                      controller: _scrollControllers[0]),
                                  _buildGuided(context,
                                      controller: _scrollControllers[1]),
                                  _buildTools(context,
                                      controller: _scrollControllers[2]),
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
  Widget _topHero(
      {required String title,
      required String subtitle,
      bool collapsed = false,
      double textOpacity = 1.0}) {
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
                  theme.colorScheme.surface.withValues(alpha: 0.18),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.22),
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
                  child: AnimatedOpacity(
                    opacity: textOpacity,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ) ??
                              const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ) ??
                                  const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
    return Listener(
      onPointerSignal: _onTabBarPointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onTabBarDragStart,
        onHorizontalDragUpdate: _onTabBarDragUpdate,
        onHorizontalDragEnd: _onTabBarDragEnd,
        child: TabBar(
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
          tabs: const [
            Tab(text: 'Design'),
            Tab(text: 'AI Guided'),
            Tab(text: 'Design Tools'),
          ],
        ),
      ),
    );
  }

  void _onTabBarPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Determine primary scroll axis, map: down or left -> next; up or right -> previous
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    final bool horizontal = dx.abs() > dy.abs();
    final double primary = horizontal
        ? -dx
        : dy; // left is next (positive), down is next (positive)

    // Accumulate and step with a threshold to avoid overscrolling multiple tabs per tick
    _tabWheelAccum += primary;
    const double threshold = 40.0; // pixels; adjust to taste

    while (_tabWheelAccum >= threshold) {
      _tabWheelAccum -= threshold;
      _animateToTab(_tab.index + 1);
    }
    while (_tabWheelAccum <= -threshold) {
      _tabWheelAccum += threshold;
      _animateToTab(_tab.index - 1);
    }
  }

  void _animateToTab(int i) {
    final next = i.clamp(0, _tabCount - 1);
    if (next == _tab.index) return;
    _tab.animateTo(next,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic);
  }

  // Swipe handling over TabBar
  double _dragAccumX = 0.0;
  void _onTabBarDragStart(DragStartDetails d) {
    _dragAccumX = 0.0;
  }

  void _onTabBarDragUpdate(DragUpdateDetails d) {
    _dragAccumX += d.delta.dx; // right is positive, left is negative
  }

  void _onTabBarDragEnd(DragEndDetails d) {
    const double distanceThreshold = 40.0; // px
    const double velocityThreshold = 600.0; // px/s

    final double v = d.primaryVelocity ?? 0.0; // right positive

    // Prefer velocity; fall back to distance
    if (v.abs() >= velocityThreshold) {
      if (v > 0) {
        _animateToTab(_tab.index - 1); // swipe right -> previous
      } else {
        _animateToTab(_tab.index + 1); // swipe left -> next
      }
      return;
    }

    if (_dragAccumX.abs() >= distanceThreshold) {
      if (_dragAccumX > 0) {
        _animateToTab(_tab.index - 1);
      } else {
        _animateToTab(_tab.index + 1);
      }
    }
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your Color Story",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
            _ToolItem(
                label: "Interview",
                onTap: () =>
                    Navigator.of(context).pushNamed('/interview/home')),
            _ToolItem(
                label: "Roller",
                onTap: () => _open(context, const RollerScreen())),
          ]),
          _SectionHeader(title: "Refine your Palette"),
          _ToolRow(items: [
            _ToolItem(
                label: "Learn",
                onTap: () => _open(context, const LearnScreen())),
          ]),
          _SectionHeader(title: "See your Palette"),
          _ToolRow(items: [
            _ToolItem(
                label: "Visualizer",
                onTap: () => _open(context, const VisualizerScreen())),
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
            _ToolItem(
                label: "Interview",
                onTap: () =>
                    Navigator.of(context).pushNamed('/interview/home')),
            _ToolItem(
                label: "Roller",
                onTap: () => _open(context, const RollerScreen())),
          ]),
          _SectionHeader(title: "Refine your Palette"),
          _ToolRow(items: [
            _ToolItem(
                label: "Learn",
                onTap: () => _open(context, const LearnScreen())),
          ]),
          _SectionHeader(title: "See your Palette"),
          _ToolRow(items: [
            _ToolItem(
                label: "Visualizer",
                onTap: () => _open(context, const VisualizerScreen())),
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
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('No project found')));
        }
        break;
      default:
        // default to Create hub or show dialog
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This step opens from its tool.')));
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
                    border: Border.all(
                        color: theme.colorScheme.outline.withAlpha(26)),
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

/// Compact section intro used at the top of the Design tab
class _SectionIntro extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionIntro({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(170),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureCardData {
  final String semanticLabel;
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;
  const _FeatureCardData({
    required this.semanticLabel,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });
}

class _FeatureGrid extends StatelessWidget {
  final List<_FeatureCardData> cards;
  const _FeatureGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 14;
        final bool twoCols = constraints.maxWidth >= 640;
        final double cardWidth = twoCols
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((c) {
            return SizedBox(
              width: cardWidth,
              child: _FeatureCard(data: c),
            );
          }).toList(),
        );
      },
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final _FeatureCardData data;
  const _FeatureCard({required this.data});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool v) => setState(() => _hovered = v);
  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;
    final double scale = _pressed ? 0.985 : (_hovered ? 1.01 : 1.0);
    final double elevation = _pressed ? 2 : (_hovered ? 6 : 3);

    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() {}),
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: Semantics(
          label: data.semanticLabel,
          button: true,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: scale),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            builder: (context, s, child) =>
                Transform.scale(scale: s, child: child),
            child: Material(
              color: Colors.transparent,
              elevation: elevation,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTapDown: (_) => _setPressed(true),
                onTapCancel: () => _setPressed(false),
                onTap: () {
                  _setPressed(false);
                  widget.data.onTap();
                },
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: data.gradient,
                  ),
                  child: Stack(
                    children: [
                      // Soft decorative blobs for subtle flair
                      Positioned(
                        top: -40,
                        right: -30,
                        child:
                            _Blob(color: Colors.white.withAlpha(38), size: 140),
                      ),
                      Positioned(
                        bottom: -30,
                        left: -20,
                        child:
                            _Blob(color: Colors.white.withAlpha(26), size: 120),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withAlpha(40),
                                  width: 1,
                                ),
                              ),
                              child: Icon(data.icon,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              data.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data.subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withAlpha(220),
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.12),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: widget.data.onTap,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(data.actionLabel),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.arrow_forward_rounded,
                                          size: 18),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Use a radial gradient for a soft blob feel
          gradient: RadialGradient(
            colors: [color, color.withAlpha(0)],
          ),
        ),
      ),
    );
  }
}
