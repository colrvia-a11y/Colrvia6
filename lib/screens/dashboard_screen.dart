// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';
import '../services/photo_library_service.dart';
import '../models/project.dart';
import '../widgets/auth_dialog.dart';
import 'package:color_canvas/screens/roller_screen.dart';
import 'explore_screen.dart';
import 'color_plan_screen.dart';
import 'visualizer_screen.dart';
import 'settings_screen.dart';
import 'projects_screen.dart';
import 'photo_library_screen.dart';
import 'package:color_canvas/utils/debug_logger.dart';
import 'package:color_canvas/widgets/colr_via_icon_button.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _reduceMotion = false;
  bool _hasCheckedReduceMotion = false;
  int _photoCount = 0;

  @override
  void initState() {
    super.initState();
    Debug.info('DashboardScreen', 'initState', 'Component initializing');
    // Defer non-UI work to after first frame to speed first paint
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Track dashboard opened
      AnalyticsService.instance.logDashboardOpened();
      // Load photo count
      _loadPhotoCount();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Debug.info('DashboardScreen', 'didChangeDependencies',
        'Dependencies changed, hasCheckedReduceMotion: $_hasCheckedReduceMotion');
    // Only check reduce motion once to prevent infinite MediaQuery access
    if (!_hasCheckedReduceMotion) {
      _checkReduceMotion();
      _hasCheckedReduceMotion = true;
    }
  }

  void _checkReduceMotion() {
    Debug.mediaQuery(
        'DashboardScreen', '_checkReduceMotion', 'maybeDisableAnimationsOf');
    final newReduceMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduceMotion != newReduceMotion) {
      Debug.info('DashboardScreen', '_checkReduceMotion',
          'Reduce motion changed: $_reduceMotion -> $newReduceMotion');
      _reduceMotion = newReduceMotion;
    }
  }

  Future<void> _loadPhotoCount() async {
    try {
      final count = await PhotoLibraryService.getPhotoCount();
      if (mounted) {
        setState(() {
          _photoCount = count;
        });
      }
    } catch (e) {
      Debug.error('DashboardScreen', '_loadPhotoCount', 
          'Failed to load photo count: $e');
    }
  }

  Stream<List<ProjectDoc>> _getProjectsStream() {
    return ProjectService.myProjectsStream();
  }

  void _showSignInPrompt() {
    showDialog(
      context: context,
      builder: (context) => AuthDialog(
        onAuthSuccess: () {
          Navigator.pop(context);
          // No need to call setState - StreamBuilder will automatically rebuild
          // when FirebaseService.currentUser changes
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Debug.build('DashboardScreen', 'build',
        details:
            'reduceMotion: $_reduceMotion, hasCheckedReduceMotion: $_hasCheckedReduceMotion');

    // Brand colors matching visualizer design
    const Color forestGreen = Color(0xFF404934);
    const Color warmPeach = Color(0xFFf2b897);
    const Color creamWhite = Color(0xFFFFFBF7);

    return Scaffold(
      backgroundColor: creamWhite,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              creamWhite,
              forestGreen.withValues(alpha: 0.03),
              warmPeach.withValues(alpha: 0.05),
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Elevated Header with Brand Styling
              SliverPersistentHeader(
                pinned: true,
                delegate: _AccountHeaderDelegate(),
              ),

              // Welcome Hero Section
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                sliver: SliverToBoxAdapter(child: _WelcomeHeroSection()),
              ),

              // Quick Actions Grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverToBoxAdapter(child: _QuickActionsGrid()),
              ),

              // Recent Projects Section
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Recent Projects',
                    icon: Icons.history_rounded,
                  ),
                ),
              ),

              StreamBuilder<List<ProjectDoc>>(
                stream: _getProjectsStream(),
                builder: (context, snapshot) {
                  if (FirebaseService.currentUser == null) {
                    return SliverToBoxAdapter(
                        child: _BrandedSignInCard(onSignIn: _showSignInPrompt));
                  }

                  final projects = snapshot.data ?? const <ProjectDoc>[];
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      projects.isEmpty) {
                    return SliverToBoxAdapter(
                        child: _BrandedProjectsSkeleton());
                  }
                  if (projects.isEmpty) {
                    return SliverToBoxAdapter(child: _BrandedEmptyProjects());
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList.separated(
                      itemCount: projects.length > 3
                          ? 3
                          : projects.length, // Show max 3 recent
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _BrandedProjectCard(projects[i]),
                    ),
                  );
                },
              ),

              // Library Section
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Library',
                    icon: Icons.collections_bookmark_rounded,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverToBoxAdapter(child: _BrandedLibrarySection(
                  photoCount: _photoCount,
                  onPhotoCountRefresh: _loadPhotoCount,
                )),
              ),

              // Support & Info Section
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Support & Info',
                    icon: Icons.help_center_rounded,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverToBoxAdapter(child: _BrandedSupportSection()),
              ),

              // Account Section
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Account',
                    icon: Icons.account_circle_rounded,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                sliver: SliverToBoxAdapter(child: _BrandedUserSection()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === NEW BRANDED COMPONENTS ===

class _AccountHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const Color forestGreen = Color(0xFF404934);
  static const Color warmPeach = Color(0xFFf2b897);
  static const Color creamWhite = Color(0xFFFFFBF7);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final opacity = 1.0 - (shrinkOffset / maxExtent).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            forestGreen.withValues(alpha: 0.95),
            forestGreen.withValues(alpha: 0.8),
            warmPeach.withValues(alpha: 0.15),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: forestGreen.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Account',
                      style: TextStyle(
                        color: creamWhite,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (opacity > 0.5)
                      Opacity(
                        opacity: opacity,
                        child: Text(
                          'Manage your colors and preferences',
                          style: TextStyle(
                            color: creamWhite.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: creamWhite.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: creamWhite.withValues(alpha: 0.2),
                  ),
                ),
                child: Tooltip(
                  message: 'Settings',
                  child: ColrViaIconButton(
                    icon: Icons.settings_rounded,
                    color: creamWhite,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 120;

  @override
  double get minExtent => 90;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

class _WelcomeHeroSection extends StatelessWidget {
  static const Color forestGreen = Color(0xFF404934);
  static const Color warmPeach = Color(0xFFf2b897);
  static const Color creamWhite = Color(0xFFFFFBF7);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;
    final displayName = user?.email?.split('@').first ?? 'there';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            creamWhite,
            warmPeach.withValues(alpha: 0.08),
            forestGreen.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: forestGreen.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: forestGreen.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: forestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  color: forestGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, $displayName!',
                      style: const TextStyle(
                        color: forestGreen,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Ready to create something beautiful?',
                      style: TextStyle(
                        color: forestGreen.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  static const Color forestGreen = Color(0xFF404934);
  static const Color warmPeach = Color(0xFFf2b897);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _QuickActionCard(
          icon: Icons.palette_outlined,
          title: 'Color Picker',
          subtitle: 'Build palettes',
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [forestGreen.withValues(alpha: 0.9), forestGreen],
          ),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const RollerScreen())),
        ),
        _QuickActionCard(
          icon: Icons.explore_outlined,
          title: 'Explore',
          subtitle: 'Find inspiration',
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [warmPeach.withValues(alpha: 0.9), warmPeach],
          ),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ExploreScreen())),
        ),
        _QuickActionCard(
          icon: Icons.chair_outlined,
          title: 'Visualizer',
          subtitle: 'See colors in space',
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              forestGreen.withValues(alpha: 0.7),
              warmPeach.withValues(alpha: 0.8),
            ],
          ),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const VisualizerScreen())),
        ),
        _QuickActionCard(
          icon: Icons.collections_bookmark_outlined,
          title: 'Library',
          subtitle: 'Your collection',
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              warmPeach.withValues(alpha: 0.7),
              forestGreen.withValues(alpha: 0.8),
            ],
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ProjectsScreen(initialFilter: LibraryFilter.all))),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    const Color forestGreen = Color(0xFF404934);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: forestGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: forestGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: forestGreen,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _BrandedSignInCard extends StatelessWidget {
  final VoidCallback onSignIn;
  static const Color forestGreen = Color(0xFF404934);
  static const Color warmPeach = Color(0xFFf2b897);
  static const Color creamWhite = Color(0xFFFFFBF7);

  const _BrandedSignInCard({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            forestGreen.withValues(alpha: 0.05),
            warmPeach.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: forestGreen.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: forestGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.account_circle_rounded,
              color: forestGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sign in to see your projects',
            style: TextStyle(
              color: forestGreen,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your color stories and sync across devices',
            style: TextStyle(
              color: forestGreen.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login_rounded),
              label: const Text(
                'Sign In',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: forestGreen,
                foregroundColor: creamWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandedProjectsSkeleton extends StatelessWidget {
  static const Color forestGreen = Color(0xFF404934);
  static const Color warmPeach = Color(0xFFf2b897);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: List.generate(
            3,
            (index) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        forestGreen.withValues(alpha: 0.05),
                        warmPeach.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: forestGreen.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 18,
                        width: 140 + (index * 25).toDouble(),
                        decoration: BoxDecoration(
                          color: forestGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 14,
                        width: 100,
                        decoration: BoxDecoration(
                          color: warmPeach.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ],
                  ),
                )),
      ),
    );
  }
}

class _BrandedEmptyProjects extends StatelessWidget {
  static const Color forestGreen = Color(0xFF404934);
  static const Color warmPeach = Color(0xFFf2b897);
  static const Color creamWhite = Color(0xFFFFFBF7);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            forestGreen.withValues(alpha: 0.05),
            warmPeach.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: forestGreen.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: forestGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.auto_stories_outlined,
              color: forestGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Color Stories yet',
            style: TextStyle(
              color: forestGreen,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start creating beautiful color combinations',
            style: TextStyle(
              color: forestGreen.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RollerScreen())),
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('Build'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: forestGreen,
                    foregroundColor: creamWhite,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExploreScreen())),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Explore'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: forestGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: forestGreen),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandedProjectCard extends StatelessWidget {
  final ProjectDoc project;
  static const Color forestGreen = Color(0xFF404934);
  static const Color warmPeach = Color(0xFFf2b897);
  static const Color creamWhite = Color(0xFFFFFBF7);

  const _BrandedProjectCard(this.project);

  @override
  Widget build(BuildContext context) {
    final status = {
      FunnelStage.build: 'Building',
      FunnelStage.story: 'Story drafted',
      FunnelStage.visualize: 'Visualizer ready',
      FunnelStage.share: 'Shared',
    }[project.funnelStage]!;

    final statusColor = {
      FunnelStage.build: warmPeach,
      FunnelStage.story: forestGreen.withValues(alpha: 0.8),
      FunnelStage.visualize: forestGreen,
      FunnelStage.share: warmPeach.withValues(alpha: 0.8),
    }[project.funnelStage]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openStage(context, project),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                creamWhite,
                forestGreen.withValues(alpha: 0.03),
                warmPeach.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: forestGreen.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: forestGreen.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getStageIcon(project.funnelStage),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: const TextStyle(
                        color: forestGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Updated ${_timeAgo(project.updatedAt)}',
                      style: TextStyle(
                        color: forestGreen.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: forestGreen.withValues(alpha: 0.4),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStageIcon(FunnelStage stage) {
    switch (stage) {
      case FunnelStage.build:
        return Icons.palette_outlined;
      case FunnelStage.story:
        return Icons.menu_book_outlined;
      case FunnelStage.visualize:
        return Icons.chair_outlined;
      case FunnelStage.share:
        return Icons.ios_share_outlined;
    }
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  void _openStage(BuildContext context, ProjectDoc p) {
    switch (p.funnelStage) {
      case FunnelStage.build:
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RollerScreen(projectId: p.id)));
        break;
      case FunnelStage.story:
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ColorPlanScreen(projectId: p.id)));
        break;
      case FunnelStage.visualize:
      case FunnelStage.share:
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const VisualizerScreen()));
        break;
    }
  }
}

class _BrandedLibrarySection extends StatelessWidget {
  static const Color forestGreen = Color(0xFF404934);
  static const Color warmPeach = Color(0xFFf2b897);
  static const Color creamWhite = Color(0xFFFFFBF7);

  final int photoCount;
  final VoidCallback onPhotoCountRefresh;

  const _BrandedLibrarySection({
    required this.photoCount,
    required this.onPhotoCountRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            creamWhite,
            forestGreen.withValues(alpha: 0.03),
            warmPeach.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: forestGreen.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: forestGreen.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: forestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.collections_bookmark_rounded,
                  color: forestGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Collection',
                      style: TextStyle(
                        color: forestGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Browse saved palettes and stories',
                      style: TextStyle(
                        color: forestGreen.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // First row - Palettes and Stories
          Row(
            children: [
              Expanded(
                child: _BrandedLibraryButton(
                  icon: Icons.palette_outlined,
                  title: 'Palettes',
                  count: '12',
                  colors: [forestGreen, forestGreen.withValues(alpha: 0.8)],
                  onTap: () =>
                      _openLibraryWithFilter(context, LibraryFilter.palettes),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BrandedLibraryButton(
                  icon: Icons.auto_stories_outlined,
                  title: 'Stories',
                  count: '8',
                  colors: [warmPeach, warmPeach.withValues(alpha: 0.8)],
                  onTap: () =>
                      _openLibraryWithFilter(context, LibraryFilter.stories),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row - Photo Library (full width)
          _BrandedLibraryButton(
            icon: Icons.photo_library_outlined,
            title: 'Photo Library',
            count: photoCount.toString(),
            colors: [const Color(0xFF6A5ACD), const Color(0xFF6A5ACD).withValues(alpha: 0.8)], // Purple accent
            onTap: () => _openPhotoLibrary(context),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _openLibraryWithFilter(context, LibraryFilter.all),
              icon: const Icon(Icons.library_books_outlined),
              label: const Text(
                'View All',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: forestGreen.withValues(alpha: 0.1),
                foregroundColor: forestGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openLibraryWithFilter(BuildContext context, LibraryFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectsScreen(initialFilter: filter),
      ),
    );
  }

  void _openPhotoLibrary(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PhotoLibraryScreen(),
      ),
    );
    // Refresh photo count when returning from photo library
    onPhotoCountRefresh();
  }
}

class _BrandedLibraryButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String count;
  final List<Color> colors;
  final VoidCallback onTap;

  const _BrandedLibraryButton({
    required this.icon,
    required this.title,
    required this.count,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors.map((c) => c.withValues(alpha: 0.15)).toList(),
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.first.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: colors.first,
                    size: 20,
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.first.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count,
                      style: TextStyle(
                        color: colors.first,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: colors.first,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandedSupportSection extends StatelessWidget {
  static const Color forestGreen = Color(0xFF404934);
  static const Color warmPeach = Color(0xFFf2b897);
  static const Color creamWhite = Color(0xFFFFFBF7);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            creamWhite,
            forestGreen.withValues(alpha: 0.03),
            warmPeach.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: forestGreen.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          _buildBrandedMenuItem(
            context,
            icon: Icons.auto_awesome_rounded,
            title: "What's New",
            subtitle: 'Latest features and updates',
            onTap: () => _showComingSoon(context, "What's New"),
          ),
          const SizedBox(height: 8),
          _buildBrandedMenuItem(
            context,
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Feedback',
            subtitle: 'Share your thoughts',
            onTap: () => _showComingSoon(context, 'Feedback'),
          ),
          const SizedBox(height: 8),
          _buildBrandedMenuItem(
            context,
            icon: Icons.help_outline_rounded,
            title: 'FAQ',
            subtitle: 'Get quick answers',
            onTap: () => _showComingSoon(context, 'FAQ'),
          ),
          const SizedBox(height: 8),
          _buildBrandedMenuItem(
            context,
            icon: Icons.support_agent_rounded,
            title: 'Support',
            subtitle: 'Get help from our team',
            onTap: () => _showComingSoon(context, 'Support'),
          ),
          const SizedBox(height: 8),
          _buildBrandedMenuItem(
            context,
            icon: Icons.gavel_outlined,
            title: 'Legal',
            subtitle: 'Terms and privacy',
            onTap: () => _showComingSoon(context, 'Legal'),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandedMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: forestGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: forestGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: forestGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: forestGreen.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: forestGreen.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: forestGreen,
      ),
    );
  }
}

class _BrandedUserSection extends StatelessWidget {
  static const Color forestGreen = Color(0xFF404934);
  static const Color warmPeach = Color(0xFFf2b897);
  static const Color creamWhite = Color(0xFFFFFBF7);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            creamWhite,
            forestGreen.withValues(alpha: 0.03),
            warmPeach.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: forestGreen.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: forestGreen.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          if (user != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        forestGreen.withValues(alpha: 0.8),
                        warmPeach.withValues(alpha: 0.6)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    user.email?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: creamWhite,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.email ?? 'User',
                        style: const TextStyle(
                          color: forestGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: forestGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Signed in',
                          style: TextStyle(
                            color: forestGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await FirebaseService.signOut();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Signed out successfully'),
                          backgroundColor: forestGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error signing out: $e'),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: forestGreen.withValues(alpha: 0.1),
                  foregroundColor: forestGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: forestGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: forestGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Not signed in',
                        style: TextStyle(
                          color: forestGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Sign in to sync your projects',
                        style: TextStyle(
                          color: forestGreen.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/login');
                },
                icon: Icon(Icons.login_rounded),
                label: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: forestGreen,
                  foregroundColor: creamWhite,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Divider(
            color: forestGreen.withValues(alpha: 0.2),
            height: 1,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.palette_rounded,
                color: forestGreen.withValues(alpha: 0.5),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Colrvia v1.0.0',
                style: TextStyle(
                  color: forestGreen.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
