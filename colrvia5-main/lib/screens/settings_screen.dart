import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:color_canvas/services/firebase_service.dart';
import 'package:color_canvas/firestore/firestore_data_schema.dart';
import 'package:color_canvas/screens/login_screen.dart';
import 'package:color_canvas/screens/admin_screen.dart';
import 'package:color_canvas/screens/simple_firebase_test.dart';
import 'package:color_canvas/services/accessibility_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'diagnostics_screen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  // Brand colors for immersive experience
  static const Color _forestGreen = Color(0xFF404934);
  static const Color _warmPeach = Color(0xFFF2B897);
  static const Color _creamWhite = Color(0xFFFFFDF8);
  static const Color _forestGreen80 = Color.fromRGBO(64, 73, 52, 0.8);

  // Animation controllers for micro-interactions
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;

  // Animations for competitive edge
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _harmonyModesEnabled = true;
  bool _brandDiversityEnabled = true;
  bool _isAdmin = false;

  // Color Story preferences
  bool _autoPlayStoryAudio = false;
  bool _reduceMotion = false;
  bool _cbFriendlyVariant = false;
  bool _wifiOnlyForStoryAssets = false;
  String _defaultStoryVisibility = 'private';
  String _ambientAudioMode = 'off';
  int _paintCount = 0;
  int _brandCount = 0;
  String _appVersion = '';
  

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _loadAppStats();
    _loadVersion();
  }

  void _initializeAnimations() {
    // Initialize animation controllers for immersive micro-interactions
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Create animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
    _shimmerController.repeat(reverse: true);
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = '${info.version} (${info.buildNumber})');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseService.currentUser;
    if (user != null) {
      try {
        final profile = await FirebaseService.getUserProfile(user.uid);
        final adminStatus = await FirebaseService.checkAdminStatus(user.uid);
        await _loadColorStoryPreferences();
        setState(() {
          _userProfile = profile;
          _isAdmin = adminStatus;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadColorStoryPreferences() async {
    final user = FirebaseService.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseService.getUserDocument(user.uid);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        await AccessibilityService.instance.load();
        setState(() {
          _autoPlayStoryAudio = data['autoPlayStoryAudio'] ?? false;
          _reduceMotion = AccessibilityService.instance.reduceMotion;
          _cbFriendlyVariant =
              AccessibilityService.instance.cbFriendlyEnabled;
          _wifiOnlyForStoryAssets = data['wifiOnlyAssets'] ?? false;
          _defaultStoryVisibility = data['defaultStoryVisibility'] ?? 'private';
          _ambientAudioMode = data['ambientAudioMode'] ?? 'off';
        });
      } else {
        await AccessibilityService.instance.load();
        setState(() {
          _reduceMotion = AccessibilityService.instance.reduceMotion;
          _cbFriendlyVariant =
              AccessibilityService.instance.cbFriendlyEnabled;
        });
      }
    } catch (e) {
      // Use defaults if loading fails
    }
  }

  Future<void> _saveColorStoryPreferences() async {
    final user = FirebaseService.currentUser;
    if (user == null) return;

    try {
      await FirebaseService.updateUserColorStoryPreferences(
        uid: user.uid,
        autoPlayStoryAudio: _autoPlayStoryAudio,
        reduceMotion: _reduceMotion,
        wifiOnlyAssets: _wifiOnlyForStoryAssets,
        defaultStoryVisibility: _defaultStoryVisibility,
        ambientAudioMode: _ambientAudioMode,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    }
  }

  Future<void> _loadAppStats() async {
    try {
      final paints = await FirebaseService.getAllPaints();
      final brands = await FirebaseService.getAllBrands();
      setState(() {
        _paintCount = paints.length;
        _brandCount = brands.length;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseService.signOut();
      setState(() {
        _userProfile = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  Future<void> _toggleAdminMode() async {
    final user = FirebaseService.currentUser;
    if (user == null) return;

    try {
      final newAdminStatus = !_isAdmin;
      await FirebaseService.toggleAdminPrivileges(user.uid, newAdminStatus);

      // Reload user profile to get updated data
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newAdminStatus
                ? 'Admin privileges enabled'
                : 'Admin privileges disabled'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating admin status: $e')),
        );
      }
    }
  }

  void _showLoginScreen() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    )
        .then((_) {
      // Refresh user data when returning from login
      _loadUserData();
    });
  }

  Future<void> _showFirebaseDebug(BuildContext context) async {
    final firebaseStatus = await FirebaseService.getFirebaseStatus();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Firebase Debug Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Auth Status: ${firebaseStatus['isAuthenticated'] ?? 'Unknown'}'),
                const SizedBox(height: 8),
                Text('User ID: ${firebaseStatus['userId'] ?? 'None'}'),
                const SizedBox(height: 8),
                Text('User Email: ${firebaseStatus['userEmail'] ?? 'None'}'),
                const SizedBox(height: 8),
                Text(
                    'Firestore Online: ${firebaseStatus['isFirestoreOnline'] ?? 'Unknown'}'),
                const SizedBox(height: 8),
                if (firebaseStatus['error'] != null) ...[
                  const Text('Error:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 4),
                  Text('${firebaseStatus['error']}',
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                ],
                const Divider(),
                const Text('Issues:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                    '• Using placeholder Firebase project\n• Only web platform configured\n• Security rules not deployed\n• Need to connect real Firebase project'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _creamWhite,
              _creamWhite.withValues(alpha: 0.8),
              _warmPeach.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildBrandedAppBar(),
            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: _buildLoadingIndicator(),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Column(
                            children: [
                              _buildProfileHeader(),
                              const SizedBox(height: 24),
                              _buildPreferencesSection(),
                              const SizedBox(height: 24),
                              _buildColorStorySection(),
                              const SizedBox(height: 24),
                              _buildAppInfoSection(),
                              const SizedBox(height: 24),
                              _buildAboutSection(),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBrandedAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _forestGreen,
              _forestGreen.withValues(alpha: 0.9),
              _forestGreen.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: FlexibleSpaceBar(
          title: AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _creamWhite,
                      _warmPeach.withValues(alpha: 0.8),
                      _creamWhite,
                    ],
                    stops: [
                      _shimmerAnimation.value - 0.3,
                      _shimmerAnimation.value,
                      _shimmerAnimation.value + 0.3,
                    ].map((e) => e.clamp(0.0, 1.0)).toList(),
                  ).createShader(bounds);
                },
                child: const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 24,
                  ),
                ),
              );
            },
          ),
          centerTitle: true,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_forestGreen, _warmPeach],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading Settings...',
            style: TextStyle(
              color: _forestGreen,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final user = FirebaseService.currentUser;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _forestGreen.withValues(alpha: 0.05),
            _warmPeach.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _forestGreen.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _forestGreen.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_forestGreen, _warmPeach],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _forestGreen.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: user?.photoURL != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.network(
                            user!.photoURL!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          user?.email?.substring(0, 1).toUpperCase() ?? 'G',
                          style: const TextStyle(
                            color: _creamWhite,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user != null) ...[
                        Text(
                          user.email ?? 'User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _forestGreen,
                          ),
                        ),
                        if (_userProfile != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _userProfile!.plan == 'free'
                                  ? _forestGreen.withValues(alpha: 0.1)
                                  : _warmPeach.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_userProfile!.plan.toUpperCase()} PLAN',
                              style: TextStyle(
                                color: _userProfile!.plan == 'free'
                                    ? _forestGreen
                                    : _forestGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_userProfile!.paletteCount}/10 palettes saved',
                            style: TextStyle(
                              fontSize: 12,
                              color: _forestGreen.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ] else ...[
                        const Text(
                          'Guest User',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: _forestGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (user != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildBrandedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Upgrade to Pro feature coming soon'),
                          ),
                        );
                      },
                      icon: Icons.star_rounded,
                      label: 'Upgrade to Pro',
                      isSecondary: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBrandedButton(
                      onPressed: _signOut,
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      isDestructive: true,
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildBrandedButton(
                onPressed: _showLoginScreen,
                icon: Icons.login_rounded,
                label: 'Sign In',
                isPrimary: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBrandedButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    bool isPrimary = false,
    bool isSecondary = false,
    bool isDestructive = false,
  }) {
    return SizedBox(
      height: 48,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            elevation: isPrimary ? 4 : 2,
            shadowColor: isPrimary
                ? _forestGreen.withValues(alpha: 0.3)
                : Colors.transparent,
            backgroundColor: isPrimary
                ? _forestGreen
                : isDestructive
                    ? Colors.red.shade400
                    : isSecondary
                        ? _creamWhite
                        : _warmPeach.withValues(alpha: 0.1),
            foregroundColor: isPrimary
                ? _creamWhite
                : isDestructive
                    ? Colors.white
                    : _forestGreen,
            side: BorderSide(
              color: isPrimary
                  ? Colors.transparent
                  : isDestructive
                      ? Colors.transparent
                      : _forestGreen.withValues(alpha: 0.2),
              width: 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _forestGreen.withValues(alpha: 0.03),
            _warmPeach.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _forestGreen.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _forestGreen.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_forestGreen, _warmPeach],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: _creamWhite,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Preferences',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _forestGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildBrandedSwitch(
              title: 'Enable Harmony Modes',
              subtitle: 'Use color theory-based palette generation',
              value: _harmonyModesEnabled,
              onChanged: (value) {
                setState(() => _harmonyModesEnabled = value);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(height: 12),
            _buildBrandedSwitch(
              title: 'Brand Diversity',
              subtitle: 'Prefer mixing different paint brands',
              value: _brandDiversityEnabled,
              onChanged: (value) {
                setState(() => _brandDiversityEnabled = value);
                HapticFeedback.selectionClick();
              },
            ),
            if (FirebaseService.currentUser != null) ...[
              const SizedBox(height: 16),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _forestGreen.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildBrandedSwitch(
                title: 'Admin Mode',
                subtitle: 'Enable admin privileges for data management',
                value: _isAdmin,
                onChanged: (value) => _toggleAdminMode(),
                isSpecial: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBrandedSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    bool isSpecial = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value
            ? (isSpecial
                ? Colors.orange.withValues(alpha: 0.1)
                : _forestGreen.withValues(alpha: 0.08))
            : _creamWhite.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? (isSpecial
                  ? Colors.orange.withValues(alpha: 0.3)
                  : _forestGreen.withValues(alpha: 0.2))
              : _forestGreen.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _forestGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: _forestGreen.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isSpecial ? Colors.orange : _forestGreen)
                      .withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: isSpecial ? Colors.orange : _forestGreen,
              activeTrackColor: (isSpecial ? Colors.orange : _forestGreen)
                  .withValues(alpha: 0.3),
              inactiveThumbColor: _forestGreen.withValues(alpha: 0.5),
              inactiveTrackColor: _forestGreen.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorStorySection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _warmPeach.withValues(alpha: 0.05),
            _forestGreen.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _warmPeach.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _warmPeach.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_warmPeach, _forestGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: _creamWhite,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Color Stories',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _forestGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'AI-generated immersive color experiences',
              style: TextStyle(
                fontSize: 14,
                color: _forestGreen.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            _buildBrandedSwitch(
              title: 'Auto-play Story Audio',
              subtitle: 'Automatically play ambient audio when viewing stories',
              value: _autoPlayStoryAudio,
              onChanged: (value) {
                setState(() => _autoPlayStoryAudio = value);
                _saveColorStoryPreferences();
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(height: 12),
            _buildBrandedSwitch(
              title: 'Reduce Motion',
              subtitle: 'Turn off parallax and background animations',
              value: _reduceMotion,
              onChanged: (value) {
                setState(() => _reduceMotion = value);
                AccessibilityService.instance.setReduceMotion(value);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(height: 12),
            _buildBrandedSwitch(
              title: 'Color-blind Friendly Variant',
              subtitle: 'Adds a CB-safe palette option in Roller',
              value: _cbFriendlyVariant,
              onChanged: (value) {
                setState(() => _cbFriendlyVariant = value);
                AccessibilityService.instance.setCbFriendly(value);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(height: 12),
            _buildBrandedSwitch(
              title: 'Wi-Fi Only for Assets',
              subtitle: 'Download images and audio only on Wi-Fi',
              value: _wifiOnlyForStoryAssets,
              onChanged: (value) {
                setState(() => _wifiOnlyForStoryAssets = value);
                _saveColorStoryPreferences();
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(height: 16),
            _buildVisibilityDropdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityDropdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _creamWhite.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _forestGreen.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Default Story Visibility',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _forestGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'New stories will be $_defaultStoryVisibility by default',
            style: TextStyle(
              fontSize: 13,
              color: _forestGreen.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: _forestGreen.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _forestGreen.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _defaultStoryVisibility,
                icon: const Icon(Icons.expand_more, color: _forestGreen),
                style: const TextStyle(
                  color: _forestGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'private',
                    child: Row(
                      children: [
                        Icon(Icons.lock, size: 16),
                        SizedBox(width: 8),
                        Text('Private'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'unlisted',
                    child: Row(
                      children: [
                        Icon(Icons.link_off, size: 16),
                        SizedBox(width: 8),
                        Text('Unlisted'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'public',
                    child: Row(
                      children: [
                        Icon(Icons.public, size: 16),
                        SizedBox(width: 8),
                        Text('Public'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _defaultStoryVisibility = value);
                    _saveColorStoryPreferences();
                    HapticFeedback.selectionClick();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _forestGreen.withValues(alpha: 0.08),
            _warmPeach.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _forestGreen.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _forestGreen.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_forestGreen, _warmPeach],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.palette_rounded,
                    color: _creamWhite,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Paint Database',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _forestGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _creamWhite.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _forestGreen.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildStatRow(
                      'Total Colors', '$_paintCount', Icons.color_lens_rounded),
                  const SizedBox(height: 16),
                  _buildStatRow(
                      'Paint Brands', '$_brandCount', Icons.business_rounded),
                  if (_brandCount > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2D5A3D), // _forestGreen.withValues(alpha: 0.05) - using const color
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: _forestGreen,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Includes Sherwin-Williams, Benjamin Moore, and Behr',
                              style: TextStyle(
                                fontSize: 12,
                                color: _forestGreen80,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            _buildBrandedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminScreen()),
                );
              },
              icon: Icons.admin_panel_settings_rounded,
              label: 'Import Paint Data',
              isSecondary: true,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onLongPress: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DiagnosticsScreen()),
                );
              },
              child: Text(
                'Version $_appVersion',
                style: TextStyle(
                    fontSize: 12,
                    color: _forestGreen.withValues(alpha: 0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _forestGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: _forestGreen,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: _forestGreen.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_forestGreen, _warmPeach],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _creamWhite,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _warmPeach.withValues(alpha: 0.08),
            _forestGreen.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _warmPeach.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _warmPeach.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_warmPeach, _forestGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_rounded,
                    color: _creamWhite,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'About ColorVia',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _forestGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _creamWhite.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _forestGreen.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Text(
                'ColorVia is an AI-powered color palette generator featuring real paint colors from leading brands. Create immersive color stories, visualize spaces, and discover perfect combinations.',
                style: TextStyle(
                  fontSize: 14,
                  color: _forestGreen.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _forestGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Version', '1.0.0', Icons.tag_rounded),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                      'Built with', 'Flutter & Firebase', Icons.code_rounded),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildBrandedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              const Text('Privacy Policy feature coming soon'),
                          backgroundColor: _forestGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                    icon: Icons.privacy_tip_rounded,
                    label: 'Privacy Policy',
                    isSecondary: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBrandedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                              'Terms of Service feature coming soon'),
                          backgroundColor: _forestGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                    icon: Icons.description_rounded,
                    label: 'Terms',
                    isSecondary: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBrandedButton(
              onPressed: () => _showFirebaseDebug(context),
              icon: Icons.bug_report_rounded,
              label: 'Debug Firebase Status',
              isSecondary: true,
            ),
            const SizedBox(height: 8),
            _buildBrandedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SimpleFirebaseTest()),
              ),
              icon: Icons.security_rounded,
              label: 'Test Firebase Auth',
              isSecondary: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: _forestGreen,
          size: 16,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: _forestGreen.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _forestGreen,
          ),
        ),
      ],
    );
  }
}
