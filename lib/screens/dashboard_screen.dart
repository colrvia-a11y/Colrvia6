// lib/screens/dashboard_screen.dart — Create-style hero with tabs: Account & Settings
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:color_canvas/utils/debug_logger.dart';
import 'package:color_canvas/services/analytics_service.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/services/project_service.dart';
import 'package:color_canvas/services/photo_library_service.dart';
import 'package:color_canvas/models/project.dart';

import 'package:color_canvas/screens/roller_screen.dart';
import 'package:color_canvas/screens/color_plan_screen.dart';
import 'package:color_canvas/screens/visualizer_screen.dart';
import 'package:color_canvas/screens/settings_screen.dart';
import 'package:color_canvas/screens/projects_screen.dart';
import 'package:color_canvas/screens/photo_library_screen.dart';
import 'package:color_canvas/widgets/auth_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late final TabController _tab;
  final ScrollController _scrollController = ScrollController();
  double _heroHeight = 0;
  static const double _heroMaxHeightFraction = 0.36;
  static const double _heroMinHeight = 74; // just enough for tab bar

  int _photoCount = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AnalyticsService.instance.logDashboardOpened();
      await _loadPhotoCount();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadPhotoCount() async {
    try {
      final count = await PhotoLibraryService.getPhotoCount();
      if (!mounted) return;
      setState(() => _photoCount = count);
    } catch (e) {
      Debug.error('DashboardScreen', '_loadPhotoCount', 'error: $e');
    }
  }

  void _onScroll() {
    final maxH = (MediaQuery.of(context).size.height * _heroMaxHeightFraction)
        .clamp(220.0, MediaQuery.of(context).size.height);
    final minH = _heroMinHeight;
    final scroll = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    final h = (maxH - scroll).clamp(minH, maxH);
    if (h != _heroHeight) setState(() => _heroHeight = h);
  }

  // Top hero copied from Create screen style
  Widget _topHero({
    required String title,
    required String subtitle,
    required bool collapsed,
    required double textOpacity,
  }) {
    final theme = Theme.of(context);
    const bgImage =
        'https://images.pexels.com/photos/1571460/pexels-photo-1571460.jpeg?auto=compress&cs=tinysrgb&w=1200&q=80';
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(bgImage),
                fit: BoxFit.cover,
              ),
            ),
          ),
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
          Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: textOpacity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ) ??
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ) ??
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      labelColor: theme.colorScheme.onSurface,
      unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(170),
      tabs: const [
        Tab(text: 'Account'),
        Tab(text: 'Settings'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Your Account';
    final subtitle = 'Account · Settings';
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
    final double heroTextOpacity = 1.0 - Curves.easeOutQuint.transform(fadePhase);

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
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n is ScrollUpdateNotification) _onScroll();
                          return false;
                        },
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            _AccountTab(
                              projectsStream: ProjectService.myProjectsStream(),
                              onPhotoCountRefresh: _loadPhotoCount,
                              photoCount: _photoCount,
                            ),
                            const _SettingsTab(),
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

// ACCOUNT TAB CONTENT
class _AccountTab extends StatelessWidget {
  final Stream<List<ProjectDoc>> projectsStream;
  final int photoCount;
  final VoidCallback onPhotoCountRefresh;

  const _AccountTab({
    required this.projectsStream,
    required this.photoCount,
    required this.onPhotoCountRefresh,
  });

  void _showSignInPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AuthDialog(onAuthSuccess: () {
        Navigator.pop(context);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: PrimaryScrollController.of(context),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _WelcomeCard(),
        const SizedBox(height: 16),
        _QuickActionsGridCompact(),
        const SizedBox(height: 24),
        const _RowHeader(title: 'Recent Projects', icon: Icons.history_rounded),
        const SizedBox(height: 12),
        StreamBuilder<List<ProjectDoc>>(
          stream: projectsStream,
          builder: (context, snapshot) {
            if (FirebaseService.currentUser == null) {
              return _SignInCard(onSignIn: () => _showSignInPrompt(context));
            }
            final items = snapshot.data ?? const <ProjectDoc>[];
            if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
              return const _ProjectsSkeleton();
            }
            if (items.isEmpty) return const _EmptyProjects();
            final top = items.take(3).toList();
            return Column(
              children: [
                for (final p in top) _ProjectListTile(p: p),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const _RowHeader(title: 'Library', icon: Icons.collections_bookmark_rounded),
        const SizedBox(height: 12),
        _LibraryPanel(photoCount: photoCount, onPhotoCountRefresh: onPhotoCountRefresh),
        const SizedBox(height: 24),
        const _RowHeader(title: 'Support & Info', icon: Icons.help_outline),
        const SizedBox(height: 12),
        const _SupportList(),
        const SizedBox(height: 24),
        const _RowHeader(title: 'Account', icon: Icons.account_circle),
        const SizedBox(height: 12),
        const _UserPanel(),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;
    final displayName = user?.email?.split('@').first ?? 'there';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withValues(alpha: 0.9),
            const Color(0xFFf2b897).withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF404934).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.palette_rounded, color: Color(0xFF404934)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back, $displayName!',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Ready to create something beautiful?',
                    style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsGridCompact extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // All quick action links removed as requested.
    return const SizedBox.shrink();
  }
}


class _RowHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _RowHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF404934).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF404934), size: 20),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF404934))),
    ]);
  }
}

class _SignInCard extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SignInCard({required this.onSignIn});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
  color: const Color(0xFF404934).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
  border: Border.all(color: const Color(0xFF404934).withValues(alpha: 0.15)),
      ),
      child: Column(children: [
        const Icon(Icons.account_circle_rounded, color: Color(0xFF404934), size: 32),
        const SizedBox(height: 12),
        const Text('Sign in to see your projects',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Track your work and sync across devices',
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onSignIn,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Sign In'),
          ),
        )
      ]),
    );
  }
}

class _ProjectsSkeleton extends StatelessWidget {
  const _ProjectsSkeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF404934).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
  color: const Color(0xFF404934).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_stories_outlined, color: Color(0xFF404934)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('No Color Stories yet — start by building a palette.'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const RollerScreen())),
            child: const Text('Build'),
          )
        ],
      ),
    );
  }
}

class _ProjectListTile extends StatelessWidget {
  final ProjectDoc p;
  const _ProjectListTile({required this.p});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: const Color(0xFFFFFBF7),
      leading: CircleAvatar(
  backgroundColor: const Color(0xFFf2b897).withValues(alpha: 0.25),
        child: Icon(_iconForStage(p.funnelStage), color: const Color(0xFF404934)),
      ),
      title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('Updated ${_ago(p.updatedAt)}'),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black54),
      onTap: () => _openStage(context, p),
    );
  }

  static IconData _iconForStage(FunnelStage s) {
    switch (s) {
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

  static String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  void _openStage(BuildContext context, ProjectDoc p) {
    switch (p.funnelStage) {
      case FunnelStage.build:
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const RollerScreen()));
        break;
      case FunnelStage.story:
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ColorPlanScreen(projectId: p.id)));
        break;
      case FunnelStage.visualize:
      case FunnelStage.share:
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const VisualizerScreen()));
        break;
    }
  }
}

class _LibraryPanel extends StatelessWidget {
  final int photoCount;
  final VoidCallback onPhotoCountRefresh;
  const _LibraryPanel({required this.photoCount, required this.onPhotoCountRefresh});

  void _openLibrary(BuildContext context, LibraryFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectsScreen(initialFilter: filter),
      ),
    );
  }

  void _openPhotoLibrary(BuildContext context) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PhotoLibraryScreen()));
    onPhotoCountRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: _LibraryButton(
              color: const Color(0xFF404934),
              icon: Icons.palette_outlined,
              title: 'Palettes',
              count: '—',
              onTap: () => _openLibrary(context, LibraryFilter.palettes),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LibraryButton(
              color: const Color(0xFFf2b897),
              icon: Icons.auto_stories_outlined,
              title: 'Stories',
              count: '—',
              onTap: () => _openLibrary(context, LibraryFilter.stories),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _LibraryButton(
          color: const Color(0xFF6A5ACD),
          icon: Icons.photo_library_outlined,
          title: 'Photo Library',
          count: '$photoCount',
          onTap: () => _openPhotoLibrary(context),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openLibrary(context, LibraryFilter.all),
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('View All'),
          ),
        ),
      ],
    );
  }
}

class _LibraryButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String count;
  final VoidCallback onTap;
  const _LibraryButton(
      {required this.color,
      required this.icon,
      required this.title,
      required this.count,
      required this.onTap});
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
              colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.08)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Items: $count', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(count, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SupportList extends StatelessWidget {
  const _SupportList();
  void _snack(BuildContext c, String t) {
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('$t coming soon!')));
  }
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SupportItem(
        icon: Icons.auto_awesome_rounded,
        title: "What's New",
        subtitle: 'Latest features and updates',
        onTap: () => _snack(context, "What's New"),
      ),
      _SupportItem(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Feedback',
        subtitle: 'Share your thoughts',
        onTap: () => _snack(context, 'Feedback'),
      ),
      _SupportItem(
        icon: Icons.help_outline_rounded,
        title: 'FAQ',
        subtitle: 'Get quick answers',
        onTap: () => _snack(context, 'FAQ'),
      ),
      _SupportItem(
        icon: Icons.support_agent_rounded,
        title: 'Support',
        subtitle: 'Get help from our team',
        onTap: () => _snack(context, 'Support'),
      ),
      _SupportItem(
        icon: Icons.gavel_outlined,
        title: 'Legal',
        subtitle: 'Terms and privacy',
        onTap: () => _snack(context, 'Legal'),
      ),
    ]);
  }
}

class _SupportItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SupportItem(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF404934).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF404934), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _UserPanel extends StatelessWidget {
  const _UserPanel();
  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.currentUser;
    if (user != null) {
      final email = user.email ?? '';
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.white,
            const Color(0xFFf2b897).withValues(alpha: 0.08),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF404934).withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF404934),
                child: Text(
                  email.isNotEmpty ? email.substring(0, 1).toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text('Signed in', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await FirebaseService.signOut();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signed out')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF404934).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF404934).withValues(alpha: 0.12)),
        ),
        child: Row(children: [
          const Icon(Icons.person_outline_rounded, color: Color(0xFF404934)),
          const SizedBox(width: 12),
          const Expanded(child: Text('You are not signed in.')),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Sign In'),
          ),
        ]),
      );
    }
  }
}

// SETTINGS TAB CONTENT (lite) — link out to full SettingsScreen
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: PrimaryScrollController.of(context),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white,
              const Color(0xFF404934).withValues(alpha: 0.03),
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF404934).withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Manage preferences, accessibility, account, and app info.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.tune, color: Color(0xFF404934)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child:
                        Text('Open the full settings panel for advanced options.'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
