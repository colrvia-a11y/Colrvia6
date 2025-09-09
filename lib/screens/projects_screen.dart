import 'images_section.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
// Add a prefixed import for core widgets to avoid any local shadowing
import 'package:flutter/material.dart' as m
    show Text, Column, SizedBox, Container, Positioned;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/providers.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/models/project.dart';
import 'package:color_canvas/screens/palette_detail_screen.dart';
import 'package:color_canvas/screens/roller_screen.dart' deferred as roller;
import 'package:color_canvas/screens/search_screen.dart';
import 'package:color_canvas/screens/explore_screen.dart';
import 'color_plan_screen.dart' deferred as plan;
import 'package:color_canvas/screens/visualizer_screen.dart' deferred as viz;
import 'package:color_canvas/utils/color_utils.dart';
import 'package:color_canvas/widgets/colr_via_icon_button.dart' as app;
// REGION: CODEX-ADD user-prefs-import

import 'package:color_canvas/services/analytics_service.dart';
// END REGION: CODEX-ADD user-prefs-import

enum LibraryFilter { all, palettes, stories, colors, images }

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key, this.initialFilter = LibraryFilter.all});
  final LibraryFilter initialFilter;

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen>
    with TickerProviderStateMixin {
  // Hero and tab state
  static const double _heroMaxHeightFraction = 0.32;
  static const double _heroMinHeight = 72.0;
  double _heroHeight = 0;
  late final ScrollController _scrollController;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tab = TabController(length: 4, vsync: this);
    _filter = widget.initialFilter;
    _tab.addListener(() {
      setState(() {
        _filter = LibraryFilter.values[_tab.index + 1];
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tab.dispose();
    super.dispose();
  }

  // Removed unused _isLoading; rely on provider/stream loading states
  final bool _hasPermissionError = false;
  late LibraryFilter _filter;
  String? _lastProjectId;
  String? _lastScreen;
  bool _bannerVisible = false;

// --- Place this at the very end of the file ---

  void _onScroll() {
    final maxHeight =
        (MediaQuery.of(context).size.height * _heroMaxHeightFraction)
            .clamp(220.0, MediaQuery.of(context).size.height);
    final minHeight = _heroMinHeight;
    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    double newHeight = (maxHeight - offset).clamp(minHeight, maxHeight);
    if ((newHeight - _heroHeight).abs() > 1) {
      setState(() => _heroHeight = newHeight);
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      labelColor: theme.colorScheme.onSurface,
      unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(170),
      tabs: const [
        Tab(text: 'Color Stories'),
        Tab(text: 'Palettes'),
        Tab(text: 'Colors'),
        Tab(text: 'Images'),
      ],
    );
  }

  Widget _topHero(
      {required String title,
      required String subtitle,
      required double textOpacity,
      required bool collapsed}) {
    final theme = Theme.of(context);
    const bgImage =
        'https://images.pexels.com/photos/1571460/pexels-photo-1571460.jpeg?auto=compress&cs=tinysrgb&w=1200&q=80';
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          const DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                  image: NetworkImage(bgImage), fit: BoxFit.cover),
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
                                      fontWeight: FontWeight.w800) ??
                              const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500) ??
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
                          child: _buildTabBar()),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Note: filter chips removed; tabs now control the filter state

  Widget _buildFilteredContent() {
    final projectsStream = ProjectService.myProjectsStream();
    final children = <Widget>[];
    if (_filter == LibraryFilter.stories) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child:
            m.Text('Palettes', style: Theme.of(context).textTheme.titleLarge),
      ));
      children.add(_PalettesSection());
    } else if (_filter == LibraryFilter.palettes) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: m.Text('Color Stories',
            style: Theme.of(context).textTheme.titleLarge),
      ));
      children.add(StreamBuilder<List<ProjectDoc>>(
        stream: projectsStream,
        builder: (context, snap) {
          final list = (snap.data ?? <ProjectDoc>[])
              .where(
                  (p) => p.colorStoryId != null && p.colorStoryId!.isNotEmpty)
              .toList();
          if (list.isEmpty) {
            return const m.SizedBox.shrink();
          }
          return m.Column(
            children: list.map((project) => _ProjectCard(project)).toList(),
          );
        },
      ));
    } else if (_filter == LibraryFilter.colors) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: m.Text('Saved Colors',
            style: Theme.of(context).textTheme.titleLarge),
      ));
      children.add(
        Consumer(
          builder: (context, ref, _) {
            final asyncColors = ref.watch(favoriteColorsProvider);
            return asyncColors.when(
              data: (paints) {
                if (paints.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: m.Text('No saved colors yet.')),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: paints.length,
                  itemBuilder: (context, i) {
                    final paint = paints[i];
                    return SavedColorCard(
                      paint: paint,
                      onTap: () {},
                      onRemove: () async {
                        await FirebaseService.removeFavoritePaint(paint.id);
                        ref.invalidate(favoriteColorsProvider);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: m.Text('Error loading colors: $e')),
            );
          },
        ),
      );
    } else if (_filter == LibraryFilter.images) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: m.Text('Saved Images',
            style: Theme.of(context).textTheme.titleLarge),
      ));
      children.add(const ImagesSection());
    }
    if (children.isEmpty) {
      return const SliverToBoxAdapter(child: m.SizedBox.shrink());
    }
    return SliverList(
      delegate: SliverChildListDelegate(children),
    );
  }

  // REGION: CODEX-ADD resume-banner
  Widget _resumeBanner() {
    if (!_bannerVisible || _lastProjectId == null || _lastScreen == null) {
      return const m.SizedBox.shrink();
    }
    final labelMap = {
      'roller': 'Roller',
      'plan': 'Plan',
      'visualizer': 'Visualizer',
    };
    final label = labelMap[_lastScreen] ?? _lastScreen!;
    return Dismissible(
      key: const Key('resume_banner'),
      onDismissed: (_) => setState(() => _bannerVisible = false),
      child: Container(
        color: Theme.of(context).colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            m.Text('Resume last: $label'),
            TextButton(
              onPressed: _handleResume,
              child: const m.Text('Resume'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _handleResume() async {
    final pid = _lastProjectId;
    final screen = _lastScreen;
    if (pid == null || screen == null) return;
    AnalyticsService.instance.resumeLastClicked(pid, screen);
    final nav = Navigator.of(context);
    switch (screen) {
      case 'roller':
        await roller.loadLibrary();
        if (!mounted || !nav.mounted) return;
        nav.push(MaterialPageRoute(builder: (_) => roller.RollerScreen()));
        break;
      case 'plan':
        await plan.loadLibrary();
        if (!mounted || !nav.mounted) return;
        nav.push(MaterialPageRoute(
            builder: (_) => plan.ColorPlanScreen(projectId: pid)));
        break;
      case 'visualizer':
        await viz.loadLibrary();
        if (!mounted || !nav.mounted) return;
        nav.push(MaterialPageRoute(builder: (_) => viz.VisualizerScreen()));
        break;
    }
  }
  // END REGION: CODEX-ADD resume-banner

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const m.Text('My Library')),
        body: const Center(
          child: m.Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle, size: 64, color: Colors.grey),
              m.SizedBox(height: 16),
              m.Text('Please sign in to view your palettes'),
            ],
          ),
        ),
      );
    }
    final title = 'My Library';
    final subtitle = 'All · Palettes · Color Stories';
    final maxHeroHeight =
        (MediaQuery.of(context).size.height * _heroMaxHeightFraction)
            .clamp(220.0, MediaQuery.of(context).size.height);
    if (_heroHeight == 0) _heroHeight = maxHeroHeight;
    final double collapseProgress =
        ((maxHeroHeight - _heroHeight) / (maxHeroHeight - _heroMinHeight))
            .clamp(0.0, 1.0)
            .toDouble();
    const double fadeEndAt = 0.4;
    final double fadePhase = (collapseProgress / fadeEndAt).clamp(0.0, 1.0);
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
                  textOpacity: heroTextOpacity,
                  collapsed: _heroHeight <= _heroMinHeight + 2,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    // Sticky tab bar when collapsed
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
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n is ScrollUpdateNotification) _onScroll();
                          return false;
                        },
                        child: CustomScrollView(
                          controller: _scrollController,
                          slivers: [
                            SliverToBoxAdapter(child: _resumeBanner()),
                            if (_hasPermissionError)
                              SliverToBoxAdapter(
                                child: Container(
                                  margin:
                                      const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.orange.withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_outlined,
                                          color: Colors.orange),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: m.Text(
                                          'Some data may not be available due to permission issues.',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            _buildFilteredContent(),
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
}

// Project Card for the new filter system
class _ProjectCard extends ConsumerWidget {
  const _ProjectCard(this.project);
  final ProjectDoc project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = {
      FunnelStage.build: 'Building',
      FunnelStage.story: 'Story drafted',
      FunnelStage.visualize: 'Visualizer ready',
      FunnelStage.share: 'Shared',
    }[project.funnelStage]!;

    final chips = <Widget>[];
    if ((project.roomType ?? '').isNotEmpty) {
      chips.add(Chip(
          label: m.Text(project.roomType!),
          visualDensity: VisualDensity.compact));
    }
    if ((project.styleTag ?? '').isNotEmpty) {
      chips.add(Chip(
          label: m.Text(project.styleTag!),
          visualDensity: VisualDensity.compact));
    }

    final palettesAsync = ref.watch(userPalettesProvider);
    final paletteSwatches = palettesAsync.when(
      data: (palettes) {
        UserPalette? pal;
        for (final p in palettes) {
          if (p.id == project.activePaletteId) {
            pal = p;
            break;
          }
        }
        if (pal == null) return const m.SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: pal.colors.take(5).map((c) {
              final color = ColorUtils.hexToColor(c.hex);
              return m.Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black26),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const m.SizedBox.shrink(),
      error: (_, __) => const m.SizedBox.shrink(),
    );

    return m.Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: m.Text(project.title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle:
            m.Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          paletteSwatches,
          m.Text(status),
          const m.SizedBox(height: 4),
          if (chips.isNotEmpty)
            Wrap(spacing: 6, runSpacing: -6, children: chips),
          const m.SizedBox(height: 4),
          m.Text('Updated ${_timeAgo(project.updatedAt)}',
              style: theme.textTheme.bodySmall),
        ]),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openStage(context, project),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  static Future<void> _openStage(
      BuildContext context, ProjectDoc project) async {
    switch (project.funnelStage) {
      case FunnelStage.build:
        await roller.loadLibrary();
        // ignore: use_build_context_synchronously
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => roller.RollerScreen()));
        break;
      case FunnelStage.story:
        await plan.loadLibrary();
        // ignore: use_build_context_synchronously
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => plan.ColorPlanScreen(projectId: project.id)));
        break;
      case FunnelStage.visualize:
      case FunnelStage.share:
        await viz.loadLibrary();
        // ignore: use_build_context_synchronously
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => viz.VisualizerScreen()));
        break;
    }
  }
}

// Palettes Section for the new filter system
class _PalettesSection extends ConsumerWidget {
  const _PalettesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseService.currentUser;
    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: m.Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle, size: 64, color: Colors.grey),
              m.SizedBox(height: 16),
              m.Text('Please sign in to view your palettes'),
            ],
          ),
        ),
      );
    }

    final palettesAsync = ref.watch(userPalettesProvider);

    return palettesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: m.Text('Failed to load palettes'),
        ),
      ),
      data: (palettes) {
        if (palettes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: m.Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.palette_outlined, size: 64, color: Colors.grey),
                  m.SizedBox(height: 16),
                  m.Text('No palettes yet'),
                  m.SizedBox(height: 8),
                  m.Text(
                      'Save color combinations from the Roller to see them here.'),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: palettes.length,
          itemBuilder: (context, index) {
            final palette = palettes[index];
            return EnhancedPaletteCard(
              palette: palette,
              onTap: () => _openPaletteDetail(context, palette),
              onDelete: () => _deletePalette(context, palette),
              onEdit: () => _editPaletteTags(context, palette),
              onOpenInRoller: () => _openPaletteInRoller(context, palette),
              onVisualize: () => _openPaletteInVisualizer(context, palette),
            );
          },
        );
      },
    );
  }

  void _openPaletteDetail(BuildContext context, UserPalette palette) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaletteDetailScreen(palette: palette),
      ),
    );
  }

  Future<void> _openPaletteInRoller(
      BuildContext context, UserPalette palette) async {
    final nav = Navigator.of(context);
    await roller.loadLibrary();
    if (!(nav.mounted)) return;
    nav.popUntil((route) => route.settings.name == '/' || route.isFirst);
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => roller.RollerScreen(),
      ),
    );
  }

  Future<void> _openPaletteInVisualizer(
      BuildContext context, UserPalette palette) async {
    final nav = Navigator.of(context);
    await viz.loadLibrary();
    if (!nav.mounted) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => viz.VisualizerScreen(
          initialPalette: palette.colors.map((c) => c.hex).toList(),
        ),
      ),
    );
  }

  Future<void> _deletePalette(BuildContext context, UserPalette palette) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const m.Text('Delete Palette'),
        content: m.Text('Are you sure you want to delete "${palette.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const m.Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const m.Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseService.deletePalette(palette.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: m.Text('Palette deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: m.Text('Error deleting palette: $e')),
          );
        }
      }
    }
  }

  Future<void> _editPaletteTags(
      BuildContext context, UserPalette palette) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => EditTagsDialog(
        initialTags: palette.tags,
        availableTags: [],
      ),
    );

    if (result != null) {
      try {
        final updatedPalette = palette.copyWith(
          tags: result,
          updatedAt: DateTime.now(),
        );
        await FirebaseService.updatePalette(updatedPalette);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: m.Text('Error updating tags: $e')),
          );
        }
      }
    }
  }
}

class EnhancedPaletteCard extends StatelessWidget {
  final UserPalette palette;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onOpenInRoller;
  final VoidCallback onVisualize;

  const EnhancedPaletteCard({
    super.key,
    required this.palette,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.onOpenInRoller,
    required this.onVisualize,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: palette.name,
      button: true,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ExcludeSemantics(
            child: m.Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Large color preview (top half)
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Row(
                      children: palette.colors.map((paletteColor) {
                        final color = ColorUtils.hexToColor(paletteColor.hex);

                        return Expanded(
                          child: m.Container(
                            height: double.infinity,
                            color: color,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Content section (bottom half) - Made more flexible
                Flexible(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: m.Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title and menu
                        Row(
                          children: [
                            Expanded(
                              child: m.Text(
                                palette.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              onSelected: (value) {
                                switch (value) {
                                  case 'roller':
                                    onOpenInRoller();
                                    break;
                                  case 'visualize':
                                    onVisualize();
                                    break;
                                  case 'edit':
                                    onEdit();
                                    break;
                                  case 'delete':
                                    onDelete();
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'roller',
                                  child: Row(
                                    children: [
                                      Icon(Icons.casino, size: 16),
                                      m.SizedBox(width: 8),
                                      m.Text('Open in Roller'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'visualize',
                                  child: Row(
                                    children: [
                                      Icon(Icons.auto_fix_high, size: 16),
                                      m.SizedBox(width: 8),
                                      m.Text('Visualize'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 16),
                                      m.SizedBox(width: 8),
                                      m.Text('Edit Tags'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete,
                                          size: 16, color: Colors.red),
                                      m.SizedBox(width: 8),
                                      m.Text('Delete',
                                          style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const m.SizedBox(height: 4),

                        // Metadata
                        m.Text(
                          '${palette.colors.length} colors - ${_formatDate(palette.createdAt)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        if (palette.tags.isNotEmpty) ...[
                          const m.SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: palette.tags
                                .take(2)
                                .map((tag) => m.Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: m.Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // No longer needed - using stored color info directly

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inMinutes}m ago';
    }
  }
}

class SavedColorCard extends StatelessWidget {
  final Paint paint;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const SavedColorCard({
    super.key,
    required this.paint,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);
    final isLight = color.computeLuminance() > 0.5;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: m.Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color swatch
            Expanded(
              flex: 3,
              child: m.Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Stack(
                  children: [
                    m.Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: m.Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: isLight ? Colors.black87 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Paint info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: m.Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    m.Text(
                      paint.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    m.Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        m.Text(
                          paint.brandName,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                  ),
                        ),
                        m.Text(
                          paint.code,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                    fontSize: 9,
                                    fontFamily: 'monospace',
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditTagsDialog extends StatefulWidget {
  final List<String> initialTags;
  final List<String> availableTags;

  const EditTagsDialog({
    super.key,
    required this.initialTags,
    required this.availableTags,
  });

  @override
  State<EditTagsDialog> createState() => _EditTagsDialogState();
}

class _EditTagsDialogState extends State<EditTagsDialog> {
  late List<String> _selectedTags;
  final _customTagController = TextEditingController();

  // Common tag suggestions
  final List<String> _commonTags = [
    'living room',
    'bedroom',
    'kitchen',
    'bathroom',
    'office',
    'neutral',
    'warm',
    'cool',
    'bold',
    'modern',
    'traditional',
    'cozy',
    'bright',
    'dark'
  ];

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialTags);
  }

  @override
  void dispose() {
    _customTagController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _addCustomTag() {
    final tag = _customTagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _customTagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestedTags = {..._commonTags, ...widget.availableTags}
        .where((tag) => !_selectedTags.contains(tag))
        .toList()
      ..sort();

    return AlertDialog(
      title: const m.Text('Edit Tags'),
      content: SingleChildScrollView(
        child: m.Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected tags
            if (_selectedTags.isNotEmpty) ...[
              const m.Text('Selected Tags:',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const m.SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _selectedTags
                    .map((tag) => Chip(
                          label: m.Text(tag),
                          onDeleted: () => _toggleTag(tag),
                          deleteIcon: const Icon(Icons.close, size: 16),
                        ))
                    .toList(),
              ),
              const m.SizedBox(height: 16),
            ],

            // Add custom tag
            const m.Text('Add Custom Tag:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const m.SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customTagController,
                    decoration: const InputDecoration(
                      hintText: 'Enter tag name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCustomTag(),
                  ),
                ),
                const m.SizedBox(width: 8),
                app.ColrViaIconButton(
                  icon: Icons.add,
                  color: Theme.of(context).colorScheme.onSurface,
                  onPressed: _addCustomTag,
                  semanticLabel: 'Add tag',
                ),
              ],
            ),

            const m.SizedBox(height: 16),

            // Suggested tags
            const m.Text('Suggested Tags:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const m.SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: suggestedTags
                  .map((tag) => FilterChip(
                        label: m.Text(tag),
                        onSelected: (_) => _toggleTag(tag),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const m.Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedTags),
          child: const m.Text('Save'),
        ),
      ],
    );
  }
}

class ColorDetailDialog extends StatelessWidget {
  final Paint paint;

  const ColorDetailDialog({
    super.key,
    required this.paint,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.getPaintColor(paint.hex);

    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: m.Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large color swatch
          m.Container(
            height: 200,
            width: double.infinity,
            color: color,
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: m.Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                m.Text(
                  paint.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const m.SizedBox(height: 8),
                _buildDetailRow('Brand', paint.brandName),
                _buildDetailRow('Code', paint.code),
                _buildDetailRow('Hex', paint.hex),
                const m.SizedBox(height: 16),
                m.SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const m.Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          m.SizedBox(
            width: 60,
            child: m.Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: m.Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wrapper to handle opening roller with initial colors while preserving bottom navigation
class _RollerWithInitialColorsWrapper extends StatefulWidget {
  final List<String> initialPaintIds;

  const _RollerWithInitialColorsWrapper({
    required this.initialPaintIds,
  });

  @override
  State<_RollerWithInitialColorsWrapper> createState() =>
      _RollerWithInitialColorsWrapperState();
}

class _RollerWithInitialColorsWrapperState
    extends State<_RollerWithInitialColorsWrapper> {
  @override
  void initState() {
    super.initState();
    // Navigate to home screen immediately after this widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _HomeScreenWithRollerInitialColors(
            initialPaintIds: widget.initialPaintIds,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Modified HomeScreen that starts with roller tab and initial colors
class _HomeScreenWithRollerInitialColors extends StatefulWidget {
  final List<String> initialPaintIds;

  const _HomeScreenWithRollerInitialColors({
    required this.initialPaintIds,
  });

  @override
  State<_HomeScreenWithRollerInitialColors> createState() =>
      _HomeScreenWithRollerInitialColorsState();
}

class _HomeScreenWithRollerInitialColorsState
    extends State<_HomeScreenWithRollerInitialColors> {
  int _currentIndex = 0; // Start with roller tab
  late final List<Widget> _screens = [
    // Defer Roller module and show loader until available
    Builder(
      builder: (context) {
        return FutureBuilder<void>(
          future: roller.loadLibrary(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return roller.RollerScreen();
          },
        );
      },
    ),
    const SearchScreen(),
    const ExploreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Show success message after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: m.Text('Opened palette in Roller!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.palette),
            label: 'Generate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Explore',
          ),
        ],
      ),
    );
  }
}
