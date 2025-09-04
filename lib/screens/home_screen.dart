// lib/screens/home_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../firestore/firestore_data_schema.dart' as firestore;
import '../services/user_prefs_service.dart';
import '../services/create_flow_progress.dart';
import 'create_screen.dart';
import 'projects_screen.dart';
import 'search_screen.dart';
import 'dashboard_screen.dart';
import 'roller_screen.dart';
import 'visualizer_screen.dart';
import 'package:color_canvas/widgets/via_overlay.dart';

/// Index in the bottom nav where the Via bubble lives (center slot).
const int kViaNavIndex = 2;

/// Brand peach highlight.
const Color kPeach = Color(0xFFF2B897);

/// Home scaffold with bottom tabs: Create, Projects, (Via), Search, Account.
/// Floating glass dock, adaptive labels on long-press, Via radial quick actions,
/// and a progress tick for Create flow (Interview/Roller/etc.).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  /// Called by SearchScreen to load a paint into the RollerScreen.
  void onPaintSelectedFromSearch(firestore.Paint paint) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RollerScreen(initialPaintIds: [paint.id]),
      ),
    );
  }

  int _currentIndex = 0;

  /// Screens map to non-Via nav indices:
  /// 0: Create, 1: Projects, 3: Search, 4: Account
  /// (Index 2 is Via; it opens an overlay and never becomes the active tab.)
  final _screens = <Widget>[
    const CreateHubScreen(),
    const ProjectsScreen(),
    const SearchScreen(),
    const DashboardScreen(), // Account/Dashboard (Settings accessible inside)
  ];

  @override
  void initState() {
    super.initState();
    _determineLanding();
  }

  Future<void> _determineLanding() async {
    final prefs = await UserPrefsService.fetch();
    setState(() => _currentIndex = prefs.firstRunCompleted ? 1 : 0);
  }

  void _onItemTapped(int index) {
    if (index == kViaNavIndex) {
      HapticFeedback.selectionClick();
      _openVia(contextLabel: 'Home');
      return;
    }
    setState(() => _currentIndex = index);
  }

  void _openVia({String contextLabel = 'ViaBubble'}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => ViaOverlay(contextLabel: contextLabel),
    );
  }

  int get _bodyIndex => _currentIndex > kViaNavIndex ? _currentIndex - 1 : _currentIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Make body extend behind floating dock
      body: _screens[_bodyIndex],
      bottomNavigationBar: GlassDockNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        onViaQuickAction: (ViaQuickAction action) {
          switch (action) {
            case ViaQuickAction.makePlan:
              _openVia(contextLabel: 'Quick.MakePlan');
              break;
            case ViaQuickAction.namePalette:
              _openVia(contextLabel: 'Quick.NamePalette');
              break;
            case ViaQuickAction.suggestComplements:
              _openVia(contextLabel: 'Quick.SuggestComplements');
              break;
            case ViaQuickAction.openVisualizer:
              HapticFeedback.mediumImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VisualizerScreen()),
              );
              break;
          }
        },
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Floating glass dock nav bar with center Via bubble and quick actions.
/// - Minimal, elegant, brand-peach highlight on selection
/// - Adaptive labels on long-press (toggles on/off)
/// - Progress tick on selected tab (uses CreateFlowProgress.instance)
/// ---------------------------------------------------------------------------
class GlassDockNavBar extends StatefulWidget {
  const GlassDockNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onViaQuickAction,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<ViaQuickAction> onViaQuickAction;

  @override
  State<GlassDockNavBar> createState() => _GlassDockNavBarState();
}

class _GlassDockNavBarState extends State<GlassDockNavBar> {
  bool _showLabels = false;

  // Base icons for non-Via slots, in order without Via:
  // 0: Create, 1: Projects, 2: Search, 3: Account
  static const _icons = <IconData>[
    Icons.add_circle_outline, // Create
    Icons.folder,             // Projects
    Icons.search,             // Search
    Icons.person,             // Account
  ];

  static const _labels = <String>[
    'Create', 'Projects', 'Search', 'Account'
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewPadding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 10 + (bottomInset > 0 ? 4 : 0)),
        child: GestureDetector(
          onLongPress: () {
            setState(() => _showLabels = !_showLabels);
            HapticFeedback.lightImpact();
          },
          // >>> HEIGHT CONSTRAINT so it doesn't fill the screen <<<
          child: SizedBox(
            height: 84, // 56dp buttons + padding; adjust 76–92 to taste
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (index) {
                      if (index == kViaNavIndex) {
                        return _ViaNavBubble(
                          onPressed: () => widget.onTap(index),
                          onLongPress: () => _showViaActionsOverlay(context),
                        );
                      }

                      final iconIndex = index > kViaNavIndex ? index - 1 : index;
                      final selected = widget.currentIndex == index;

                      return ValueListenableBuilder<double>(
                        valueListenable: CreateFlowProgress.instance,
                        builder: (_, createProgress, __) {
                          final isCreate = index == 0;
                          final progress = isCreate ? createProgress : 0.0;
                          return _NavSquareButton(
                            icon: _icons[iconIndex],
                            label: _labels[iconIndex],
                            selected: selected,
                            showLabel: _showLabels,
                            onPressed: () => widget.onTap(index),
                            progress: progress,
                          );
                        },
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showViaActionsOverlay(BuildContext context) {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierLabel: 'Via actions',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return Center(
          child: _ViaRadialActions(
            onAction: (a) {
              Navigator.pop(context);
              widget.onViaQuickAction(a);
            },
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final scale = Tween(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        );
        final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(opacity: fade, child: ScaleTransition(scale: scale, child: child));
      },
    );
  }
}

class _NavSquareButton extends StatelessWidget {
  const _NavSquareButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.showLabel,
    this.progress = 0.0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool showLabel;
  final double progress; // 0..1 top-edge progress bar

  @override
  Widget build(BuildContext context) {
    const double size = 56;
    final Color bgColor = Colors.black.withValues(alpha: (0.20 * 255));
    final Color iconColor = selected ? kPeach : Colors.white.withValues(alpha: (0.90 * 255));
    final Color borderColor = selected ? kPeach : Colors.transparent;

    final button = SizedBox(
      width: size,
      height: size,
      child: Semantics(
        selected: selected,
        label: label,
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    color: Colors.black.withValues(alpha: (0.10 * 255)),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: iconColor, size: 26),
                  if (selected && progress > 0)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TopTickPainter(progress: progress, color: kPeach),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!showLabel) return button;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(230),
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _TopTickPainter extends CustomPainter {
  _TopTickPainter({required this.progress, required this.color});
  final double progress; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a rounded 3px bar along the top edge, inset a bit from the sides
    final double insetX = 8.0;
    final double barHeight = 3.0;
    final double maxWidth = size.width - insetX * 2;
    final double w = (maxWidth * progress.clamp(0.0, 1.0));

    if (w <= 0) return;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(insetX, 6.0, w, barHeight),
      const Radius.circular(1.5),
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _TopTickPainter old) =>
      old.progress != progress || old.color != color;
}

/// Center Via bubble inside the dock. Long-press reveals radial quick actions.
class _ViaNavBubble extends StatelessWidget {
  const _ViaNavBubble({required this.onPressed, required this.onLongPress});
  final VoidCallback onPressed;
  final VoidCallback onLongPress;
  @override
  Widget build(BuildContext context) {
    const double diameter = 56;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Center(
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ViaBubble(
            size: diameter,
            tooltip: 'Ask Via',
            onTap: onPressed,
          ),
        ),
      ),
    );
  }
}

/// Frosted, glowing, feathered bubble (kept from your design).
class ViaBubble extends StatefulWidget {
  const ViaBubble({super.key, this.size = 64, this.tooltip, this.onTap});
  final double size;
  final String? tooltip;
  final VoidCallback? onTap;
  @override
  State<ViaBubble> createState() => _ViaBubbleState();
}

class _ViaBubbleState extends State<ViaBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;

    final bubble = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.96 : 1.0,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient glow halo
              AnimatedBuilder(
                animation: _breath,
                builder: (_, __) {
                  final t = _breath.value;
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kPeach.withValues(alpha: 0.32 + t * 0.10),
                          blurRadius: 28 + t * 10,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Frosted core with soft gradient (feathered look)
              ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
              // Via icon (bolt)
              const Icon(Icons.bolt_rounded, size: 28, color: Colors.white),
              // Thin peach ring to echo brand
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                border: Border.all(color: kPeach.withValues(alpha: 0.55), width: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Tooltip(
      message: widget.tooltip ?? 'Ask Via',
      preferBelow: false,
      child: bubble,
    );
  }
}

/// VIA radial quick actions widget (centered overlay)
class _ViaRadialActions extends StatelessWidget {
  const _ViaRadialActions({required this.onAction});
  final ValueChanged<ViaQuickAction> onAction;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (ViaQuickAction.makePlan, Icons.route, 'Make a plan'),
      (ViaQuickAction.namePalette, Icons.edit, 'Name my palette'),
      (ViaQuickAction.suggestComplements, Icons.auto_awesome, 'Complements'),
      (ViaQuickAction.openVisualizer, Icons.wallpaper, 'Visualizer'),
    ];

    return Stack(
      children: [
        Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 28),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < actions.length; i++)
                  _radialChip(
                    index: i,
                    count: actions.length,
                    icon: actions[i].$2,
                    label: actions[i].$3,
                    onTap: () => onAction(actions[i].$1),
                  ),
                Icon(Icons.bolt_rounded, color: Colors.white.withValues(alpha: 0.7), size: 36),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _radialChip({
    required int index,
    required int count,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final angle = (index / count) * (3.14159 * 2);
    const r = 78.0; // radius for chip placement
    final dx = r * MathUtils.cos(angle);
    final dy = r * MathUtils.sin(angle);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: _FrostedChip(
        icon: icon,
        label: label,
        onTap: onTap,
      ),
    );
  }
}

class _FrostedChip extends StatelessWidget {
  const _FrostedChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.08),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny math helpers (avoid dart:math import name clashes above)
class MathUtils {
  static double sin(double x) => _sin(x);
  static double cos(double x) => _cos(x);
}

// Local implementations to avoid importing 'dart:math' at top-level.
// If you prefer, replace with: `import 'dart:math' as math;` and use math.sin/cos.
const double _pi2 = 6.28318;

double _sin(double x) {
  x = x % _pi2;
  double term = x; // first term
  double sum = x;
  final double x2 = x * x;
  term *= -x2 / (2 * 3);
  sum += term;
  term *= -x2 / (4 * 5);
  sum += term;
  term *= -x2 / (6 * 7);
  sum += term;
  term *= -x2 / (8 * 9);
  sum += term;
  return sum;
}

double _cos(double x) {
  // Cos via sin(x + π/2)
  return _sin(x + 1.570795);
}

/// Quick action enum for Via radial menu.
enum ViaQuickAction {
  makePlan,
  namePalette,
  suggestComplements,
  openVisualizer,
}

