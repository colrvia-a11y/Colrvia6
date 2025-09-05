import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;
import 'dart:async';

import '../services/gemini_ai_service.dart';
import '../services/surface_detection_service.dart';
import '../services/photo_library_service.dart';
import '../services/journey/journey_service.dart';
import '../services/analytics_service.dart';
import '../firestore/firestore_data_schema.dart';
import 'photo_library_screen.dart';
import 'package:color_canvas/widgets/colr_via_icon_button.dart';

enum VisualizerMode { welcome, upload, analyze, selectSurfaces, generate, results, refine }

class VisualizerScreen extends StatefulWidget {
  final UserPalette? initialPalette;
  final String? storyId;
  const VisualizerScreen({super.key, this.initialPalette, this.storyId});

  @override
  State<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends State<VisualizerScreen>
    with TickerProviderStateMixin {
  // 🚀 AWARD-WINNING ANIMATION SYSTEM
  late AnimationController _masterController;
  late AnimationController _breathingController;
  late AnimationController _progressController;
  late AnimationController _resultsController;

  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _breathe;
  late Animation<double> _progressAnim;
  late Animation<Color?> _accentGlow;

  // 🎯 CORE STATE MANAGEMENT
  final PageController _pageController = PageController();
  VisualizerMode _currentMode = VisualizerMode.welcome;

  // 📸 IMAGE & AI STATE
  Uint8List? _originalImage;
  ImageAnalysisResult? _analysisResult;
  List<GeneratedVariant> _variants = [];
  int _selectedVariantIndex = 0;

  // 🎨 COLOR & SURFACE STATE
  final Map<SurfaceType, String> _selectedColors = {};
  UserPalette? _activePalette;
  List<String> _recentColors = [];

  // 🔧 PROCESSING STATE
  bool _isAnalyzing = false;
  String _currentStep = '';
  String _currentDescriptiveAction = '';
  late Timer? _descriptiveActionTimer;

  // 🎪 UI STATE
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.log('journey_step_view', {
      'step_id': JourneyService.instance.state.value?.currentStepId ?? 'visualizer.photo',
    });
    _initializeAnimations();
    _loadInitialData();
  }

  void _initializeAnimations() {
    // Master timeline controller
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // Breathing animation for waiting states
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    // Progress animation - slowed down to feel more realistic
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2500), // Increased from 800ms
      vsync: this,
    );

    // Results entrance
    _resultsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Animation curves
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _masterController,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _slideUp = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _masterController,
          curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack)),
    );

    _breathe = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _progressAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _accentGlow = ColorTween(
      begin: const Color(0xFF404934), // Brand forest green
      end: Theme.of(context).colorScheme.secondary, // Brand warm peach
    ).animate(
        CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut));

    _masterController.forward();
  }

  Future<void> _loadInitialData() async {
    _activePalette = widget.initialPalette;
    await _loadRecentColors();
  }

  Future<void> _loadRecentColors() async {
    // Load from local storage in production - Updated with brand colors
    _recentColors = [
      '#404934',
      '#f2b897',
      '#F5F5DC',
      '#FAF0E6',
      '#2F3728',
      '#E5A177',
      '#5A6348',
      '#FFFFFF',
      '#000000',
      '#1F251A',
      '#D8936B',
      '#6B7A5A'
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF404934), // Brand forest green base
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: AnimatedBuilder(
        animation: _masterController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideUp.value),
            child: Opacity(
              opacity: _fadeIn.value,
              child: _buildBody(),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: _currentMode != VisualizerMode.welcome
          ? ColrViaIconButton(
              icon: Icons.arrow_back_ios_new,
              color: Colors.white,
              onPressed: () {
                if (_currentMode == VisualizerMode.welcome) {
                  Navigator.pop(context);
                } else {
                  _navigateToMode(VisualizerMode.welcome);
                }
              },
              semanticLabel: 'Back',
            )
          : null,
      centerTitle: true,
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF404934), // Brand forest green
            Color(0xFF2F3728), // Deeper forest for depth
            Color(0xFF1F251A), // Rich organic dark
          ],
        ),
      ),
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildWelcomeScreen(),
          _buildUploadScreen(),
          _buildAnalysisScreen(),
          _buildSurfaceSelectionScreen(),
          _buildGenerationScreen(),
          _buildResultsScreen(),
        ],
      ),
    );
  }

  // 🎊 WELCOME SCREEN - AWARD-WINNING ENTRY POINT
  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 120),
          // Hero Animation
          AnimatedBuilder(
            animation: _breathingController,
            builder: (context, child) {
              return Transform.scale(
                scale: _breathe.value,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _accentGlow.value ?? const Color(0xFF404934),
                        _accentGlow.value?.withValues(alpha: 0.3) ??
                            const Color(0xFF404934).withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2), width: 2),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          // Title
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFE0E0E0)],
            ).createShader(bounds),
            child: const Text(
              'Transform Your Space\nwith AI Magic',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -1,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'Upload a photo or let AI create your dream space.\nSee any color palette in stunning realism.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0x33FFFFFF), // White with 20% opacity
              height: 1.5,
            ),
          ),
          const SizedBox(height: 60),
          // Action Buttons
          _buildWelcomeActions(),
          const SizedBox(height: 40),
          // Features Preview
          _buildFeaturePreview(),
        ],
      ),
    );
  }

  Widget _buildWelcomeActions() {
    return Column(
      children: [
        // Upload Photo Button
        _buildPrimaryButton(
          icon: Icons.camera_alt,
          title: 'Upload Your Photo',
          subtitle: 'Transform your real space',
          onTap: () => _navigateToMode(VisualizerMode.upload),
          gradient: const LinearGradient(
            colors: [
              Theme.of(context).colorScheme.secondary,
              Color(0xFFE5A177)
            ], // Warm peach gradient
          ),
        ),
        const SizedBox(height: 16),
        // Generate Mockup Button
        _buildPrimaryButton(
          icon: Icons.auto_awesome,
          title: 'Create AI Mockup',
          subtitle: 'Generate your dream space',
          onTap: () => _generateMockup(),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF404934),
              Color(0xFF5A6348)
            ], // Forest green gradient
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Gradient gradient,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePreview() {
    final features = [
      {
        'icon': Icons.palette,
        'title': 'Smart Colors',
        'desc': 'AI understands your style'
      },
      {
        'icon': Icons.view_in_ar,
        'title': 'Realistic Results',
        'desc': 'Photorealistic transformations'
      },
      {
        'icon': Icons.compare,
        'title': 'Compare Options',
        'desc': 'See multiple variations'
      },
      {
        'icon': Icons.save,
        'title': 'Save & Share',
        'desc': 'Keep your favorites'
      },
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Powered by AI',
            style: TextStyle(
              color: Color(0x33FFFFFF), // White with 20% opacity
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(feature['icon'] as IconData,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 20), // Brand peach
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature['title'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            feature['desc'] as String,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // 📸 UPLOAD SCREEN
  Widget _buildUploadScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 100),

          // Upload Area
          Expanded(
            child: _originalImage == null
                ? _buildUploadArea()
                : _buildImagePreview(),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          _buildUploadActions(),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _pickImageAndAnalyze,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _breathingController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _breathe.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate,
                      size: 60,
                      color: Theme.of(context).colorScheme.secondary, // Brand peach
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Tap to Upload Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload any interior or exterior space photo',
              style: TextStyle(
                color: Color(0x33FFFFFF), // White with 20% opacity
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            _buildUploadTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTips() {
    final tips = [
      'Good lighting works best',
      'Include full walls when possible',
      'Avoid blurry or dark photos',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Tips for best results:',
            style: TextStyle(
              color: Color(0x33FFFFFF), // White with 20% opacity
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF404934),
                        size: 16), // Brand forest green
                    const SizedBox(width: 8),
                    Text(
                      tip,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Image.memory(
              _originalImage!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),

            // Overlay controls
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  _buildOverlayButton(
                    icon: Icons.refresh,
                    onTap: _pickImageAndAnalyze,
                  ),
                  const SizedBox(width: 8),
                  _buildOverlayButton(
                    icon: Icons.close,
                    onTap: () => setState(() => _originalImage = null),
                  ),
                ],
              ),
            ),

            // Analysis badge
            if (_analysisResult != null)
              Positioned(
                bottom: 16,
                left: 16,
                child: _buildAnalysisBadge(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildAnalysisBadge() {
    if (_analysisResult == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF404934), // Brand forest green
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            _analysisResult!.spaceType.toString().split('.').last,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadActions() {
    return Column(
      children: [
        if (_originalImage != null) ...[
          // Analyze Image Button - Primary action
          _buildActionButton(
            title: 'Analyze Image',
            subtitle: 'Let AI understand your space',
            icon: Icons.psychology,
            color: const Color(0xFF6C5CE7), // Brand purple
            onTap: _analyzeImage,
            isLoading: _isAnalyzing,
          ),
          const SizedBox(height: 16),
          // Secondary options
          _buildSecondaryButton(
            title: 'Choose Different Image',
            onTap: _pickImageAndAnalyze,
          ),
          const SizedBox(height: 12),
        ],
        _buildSecondaryButton(
          title:
              _originalImage != null ? 'Create Mockup Instead' : 'Select Image',
          onTap: _originalImage != null ? _generateMockup : _pickImage,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(
      {required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 🔍 ANALYSIS SCREEN - Pure analysis animation
  Widget _buildAnalysisScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 100),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAnalysisAnimation(),
                  const SizedBox(height: 40),
                  _buildAnalysisStatus(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 SURFACE SELECTION SCREEN - Smart, adaptive based on AI analysis
  Widget _buildSurfaceSelectionScreen() {
    if (_analysisResult == null) {
      return const Center(
        child: Text('No analysis results available', 
          style: TextStyle(color: Colors.white)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  
                  // Compact Analysis Header (now part of scrollable content)
                  _buildCompactAnalysisHeader(),
                  const SizedBox(height: 24),
                  
                  // Dynamic surface selection based on detected surfaces
                  _buildDetectedSurfacesSelection(),
                  const SizedBox(height: 24),
                  
                  // Lighting and style context
                  _buildAnalysisContext(),
                  
                  const SizedBox(height: 100), // Extra space for bottom action button
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          if (_selectedColors.isNotEmpty) _buildAnalysisActions(),
        ],
      ),
    );
  }

  Widget _buildCompactAnalysisHeader() {
    final spaceType = _analysisResult!.spaceType;
    final surfaceCount = _analysisResult!.availableSurfaces.length;
    final confidence = (_analysisResult!.confidence * 100).round();
    
    // Get space-specific emoji and description
    final spaceEmoji = _getSpaceEmoji(spaceType);
    final spaceDescription = _getSpaceDescription(spaceType);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.15), // More subtle
            Colors.green.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12), // Smaller radius
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8), // Reduced from 12
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8), // Smaller radius
            ),
            child: Text(spaceEmoji, style: const TextStyle(fontSize: 20)), // Smaller emoji
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analysis Complete!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16, // Reduced from 18
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spaceDescription,
                  style: TextStyle(
                    color: Colors.green[200],
                    fontSize: 12, // Reduced from 14
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.format_paint, color: Colors.green[300], size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$surfaceCount surfaces detected',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Smaller padding
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16), // Smaller radius
            ),
            child: Text(
              '$confidence%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11, // Smaller text
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedSurfacesSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Surfaces to Paint',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose which detected surfaces you\'d like to visualize with new colors:',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        
        // Dynamic surface grid based on actual detection
        ...(_analysisResult!.availableSurfaces.map((surface) {
          return _buildSurfaceCard(surface);
        }).toList()),
      ],
    );
  }

  Widget _buildSurfaceCard(SurfaceType surface) {
    final isSelected = _selectedColors.containsKey(surface);
    final selectedColor = _selectedColors[surface];
    final surfaceInfo = _getSurfaceInfo(surface, _analysisResult!.spaceType);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Surface Header with context-aware description
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? Colors.blue.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  SurfaceDetectionService.getSurfaceIcon(surface),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SurfaceDetectionService.getSurfaceName(surface),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      surfaceInfo,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isSelected,
                onChanged: (value) => _selectSurface(surface),
                activeThumbColor: Colors.blue,
              ),
            ],
          ),

          // Color Selection (shown when surface is selected)
          if (isSelected) ...[
            const SizedBox(height: 16),
            _buildSmartColorSelection(surface, selectedColor),
          ],
        ],
      ),
    );
  }

  Widget _buildSmartColorSelection(SurfaceType surface, String? selectedColor) {
    // Get intelligent color suggestions based on space type and surface
    final suggestedColors = _getSmartColorSuggestions(surface, _analysisResult!.spaceType);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended Colors:',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestedColors.map((colorInfo) {
            final isSelected = selectedColor == colorInfo['hex'];
            final color = _parseColor(colorInfo['hex']!);

            return GestureDetector(
              onTap: () => _selectColorForSurface(surface, colorInfo['hex']!),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected)
                      const Icon(Icons.check, color: Colors.white, size: 16),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          'Perfect for ${_getSurfaceColorAdvice(surface, _analysisResult!.spaceType)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisContext() {
    final lighting = _analysisResult!.lightingConditions;
    final style = _analysisResult!.style;
    final dominantColors = _analysisResult!.dominantColors;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Space Analysis',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          // Lighting info
          Row(
            children: [
              Icon(_getLightingIcon(lighting), color: Colors.amber[300], size: 16),
              const SizedBox(width: 8),
              Text(
                'Lighting: ${lighting.replaceAll('_', ' ').toUpperCase()}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Style info  
          Row(
            children: [
              Icon(Icons.style, color: Colors.purple[300], size: 16),
              const SizedBox(width: 8),
              Text(
                'Style: ${style.toUpperCase()}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Existing colors
          Row(
            children: [
              Icon(Icons.palette, color: Colors.pink[300], size: 16),
              const SizedBox(width: 8),
              const Text(
                'Existing colors: ',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              ...dominantColors.take(3).map((colorHex) {
                return Container(
                  margin: const EdgeInsets.only(left: 4),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _parseColor(colorHex),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white30, width: 0.5),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisAnimation() {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Transform.scale(
          scale: _breathe.value,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                  const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(
                Icons.psychology,
                size: 80,
                color: Theme.of(context).colorScheme.secondary, // Brand peach
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalysisStatus() {
    // Descriptive actions that rotate during analysis
    final descriptiveActions = [
      'Detecting walls and surfaces...',
      'Assessing lighting conditions...',
      'Analyzing room geometry...',
      'Identifying paintable areas...',
      'Understanding space layout...',
      'Calculating surface textures...',
    ];

    return Column(
      children: [
        Text(
          _isAnalyzing ? 'Analyzing Your Space...' : 'Analysis Complete!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_isAnalyzing) ...[
          // Show rotating descriptive action
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Text(
              _currentDescriptiveAction.isEmpty 
                ? descriptiveActions[0]
                : _currentDescriptiveAction,
              key: ValueKey(_currentDescriptiveAction),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8), // Brand peach
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ] else ...[
          Text(
            'Ready to apply colors to your space',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
        if (_isAnalyzing) ...[
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return Container(
                width: 200,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progressAnim.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.secondary,
                          Color(0xFFE5A177)
                        ], // Brand peach gradient
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  void _selectColorForSurface(SurfaceType surface, String colorHex) {
    setState(() {
      _selectedColors[surface] = colorHex;
    });
  }

  Widget _buildAnalysisActions() {
    return _buildActionButton(
      title: 'Apply Colors',
      subtitle: 'Generate realistic visualizations',
      icon: Icons.palette,
      color: const Color(0xFF404934), // Brand forest green
      onTap: _startGeneration,
    );
  }

  // 🎨 GENERATION SCREEN
  Widget _buildGenerationScreen() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 100),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGenerationAnimation(),
                const SizedBox(height: 40),
                _buildGenerationStatus(),
                const SizedBox(height: 40),
                _buildGenerationProgress(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationAnimation() {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _breathingController.value * 2 * math.pi,
          child: Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFF6C5CE7),
                  Color(0xFFA29BFE),
                  Color(0xFF00B894),
                  Color(0xFF00CEC9),
                  Color(0xFF6C5CE7),
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF404934), // Brand forest green
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGenerationStatus() {
    return Column(
      children: [
        const Text(
          'Creating Magic...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _currentStep.isEmpty
              ? 'AI is transforming your space with photorealistic precision'
              : _currentStep,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildGenerationProgress() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            return Container(
              width: 250,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressAnim.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary,
                        Color(0xFF404934),
                        Color(0xFFE5A177)
                      ], // Brand gradient
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            return Text(
              '${(_progressAnim.value * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),
      ],
    );
  }

  // 🎯 RESULTS SCREEN
  Widget _buildResultsScreen() {
    return Column(
      children: [
        const SizedBox(height: 100),

        // Results Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Text(
                'Your Visualizations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildResultsToggle(),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Results Content
        Expanded(
          child: _buildResultsContent(),
        ),

        // Action Bar
        _buildResultsActions(),
      ],
    );
  }

  Widget _buildResultsToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleButton('Grid', true),
          _buildToggleButton('Compare', false),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String title, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.secondary
            : Colors.transparent, // Brand peach when active
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildResultsContent() {
    if (_variants.isEmpty) {
      return const Center(
        child: Text(
          'No results yet',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _variants.length,
      itemBuilder: (context, index) => _buildResultCard(index),
    );
  }

  Widget _buildResultCard(int index) {
    final variant = _variants[index];
    final isSelected = _selectedVariantIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedVariantIndex = index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.secondary,
                  width: 3) // Brand peach border
              : Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.secondary
                        .withValues(alpha: 0.3), // Brand peach glow
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => _showFullscreenImage(variant.imageData, variant.description),
                child: Image.memory(
                  variant.imageData,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF404934), // Brand forest green
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          variant.description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.zoom_out_map,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullscreenImage(Uint8List imageData, String description) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.black,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        description,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ColrViaIconButton(
                      icon: Icons.close,
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                      semanticLabel: 'Close',
                    ),
                  ],
                ),
              ),
              // Full-screen image
              Flexible(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  child: Image.memory(
                    imageData,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
              // Action buttons
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _saveToPhotoLibrary(imageData, description),
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Save to Library'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // Add share functionality here if needed
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF404934),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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

  Future<void> _saveToPhotoLibrary(Uint8List imageData, String description) async {
    try {
      debugPrint('💾 Saving image to photo library: $description');
      
      // Save image using PhotoLibraryService
      final photoId = await PhotoLibraryService.savePhoto(
        imageData: imageData,
        description: description,
        metadata: {
          'source': 'ai_visualizer',
          'timestamp': DateTime.now().toIso8601String(),
          'mode': _currentMode.toString(),
        },
      );
      
      debugPrint('✅ Image saved successfully with ID: $photoId');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image saved to your photo library!'),
            backgroundColor: const Color(0xFF404934),
            action: SnackBarAction(
              label: 'View Library',
              textColor: Theme.of(context).colorScheme.secondary,
              onPressed: () {
                // Navigate to photo library page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PhotoLibraryScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving to photo library: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildResultsActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              title: 'Save Favorite',
              subtitle: 'Add to your collection',
              icon: Icons.favorite,
              color: const Color(0xFF404934), // Brand forest green
              onTap: _saveFavorite,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionButton(
              title: 'Try More Colors',
              subtitle: 'Generate new variations',
              icon: Icons.refresh,
              color: Theme.of(context).colorScheme.secondary, // Brand peach
              onTap: _tryMoreColors,
            ),
          ),
        ],
      ),
    );
  }

  // 🎛️ ACTION METHODS
  void _navigateToMode(VisualizerMode mode) {
    setState(() {
      _currentMode = mode;
    });
    _pageController.animateToPage(
      mode.index,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() => _originalImage = bytes);

    try {
      final photoId = await PhotoLibraryService.savePhoto(
        imageData: bytes,
        description: 'Original Photo',
        metadata: {
          'source': 'visualizer_photo',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      await JourneyService.instance.setArtifact('photoId', photoId);
      await JourneyService.instance.completeCurrentStep();
    } catch (e) {
      debugPrint('Failed to save photo: $e');
    }

    // Note: Analysis will be triggered manually by user pressing "Analyze Image" button
    debugPrint('📷 Image selected and ready for analysis');
  }

  // Convenience: pick image and immediately analyze
  Future<void> _pickImageAndAnalyze() async {
    await _pickImage();
    if (_originalImage != null) {
      await _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    if (_originalImage == null) return;

    setState(() => _isAnalyzing = true);
    _navigateToMode(VisualizerMode.analyze);

    try {
      _progressController.forward();

      // Start rotating descriptive actions
      _startDescriptiveActionRotation();

      // Simulate analysis steps with more realistic timing
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() => _currentStep = 'Identifying room type...');

      await Future.delayed(const Duration(milliseconds: 1000));
      setState(() => _currentStep = 'Detecting surfaces...');

      await Future.delayed(const Duration(milliseconds: 900));
      setState(() => _currentStep = 'Analyzing lighting...');

      // Actual AI analysis
      debugPrint('🔍 Starting AI analysis...');
      _analysisResult =
          await SurfaceDetectionService.analyzeImage(_originalImage!);
      debugPrint(
          '✅ Analysis complete: ${_analysisResult?.availableSurfaces.length} surfaces detected');

      // Pre-select walls by default
      if (_analysisResult!.availableSurfaces.contains(SurfaceType.walls)) {
        _selectedColors[SurfaceType.walls] = _getDefaultColor();
        debugPrint(
            '🎨 Auto-selected walls with color: ${_selectedColors[SurfaceType.walls]}');
      }

      // Stop descriptive action rotation
      _stopDescriptiveActionRotation();

      setState(() {
        _isAnalyzing = false;
        _currentStep = '';
        _currentDescriptiveAction = '';
      });
      
      // Navigate to surface selection screen after analysis completes
      _navigateToMode(VisualizerMode.selectSurfaces);
    } catch (e) {
      debugPrint('❌ Analysis failed: $e');
      _stopDescriptiveActionRotation();
      setState(() {
        _isAnalyzing = false;
        _currentDescriptiveAction = '';
      });
      _showError('Failed to analyze image. Please try again.');
    }
  }

  void _startDescriptiveActionRotation() {
    final descriptiveActions = [
      'Detecting walls and surfaces...',
      'Assessing lighting conditions...',
      'Analyzing room geometry...',
      'Identifying paintable areas...',
      'Understanding space layout...',
      'Calculating surface textures...',
    ];

    int actionIndex = 0;
    setState(() {
      _currentDescriptiveAction = descriptiveActions[actionIndex];
    });

    _descriptiveActionTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (!_isAnalyzing) {
        timer.cancel();
        return;
      }
      
      actionIndex = (actionIndex + 1) % descriptiveActions.length;
      setState(() {
        _currentDescriptiveAction = descriptiveActions[actionIndex];
      });
    });
  }

  void _stopDescriptiveActionRotation() {
    _descriptiveActionTimer?.cancel();
    _descriptiveActionTimer = null;
  }

  void _selectSurface(SurfaceType surface) {
    setState(() {
      if (_selectedColors.containsKey(surface)) {
        _selectedColors.remove(surface);
      } else {
        _selectedColors[surface] = _getDefaultColor();
      }
    });
  }

  String _getDefaultColor() {
    if (_activePalette != null && _activePalette!.colors.isNotEmpty) {
      return _activePalette!.colors.first.hex;
    }
    return _recentColors.isNotEmpty ? _recentColors.first : '#F5F5F5';
  }

  Future<void> _startGeneration() async {
    if (_selectedColors.isEmpty) {
      _showError('Please select at least one surface to paint.');
      return;
    }

    debugPrint(
        '🎨 Starting generation with ${_selectedColors.length} surfaces:');
    _selectedColors.forEach((surface, color) {
      debugPrint('   - ${surface.toString().split('.').last}: $color');
    });

    _navigateToMode(VisualizerMode.generate);

    try {
      _progressController.reset();
      _progressController.forward();

      // Generate multiple variants
      final variants = <GeneratedVariant>[];

      for (int i = 0; i < _selectedColors.length; i++) {
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() => _currentStep = 'Rendering variant ${i + 1}...');

        debugPrint('🖼️ Generating variant ${i + 1}...');
        final imageData = await GeminiAIService.transformSpace(
          originalImage: _originalImage!,
          spaceType: _analysisResult!.spaceType.toString().split('.').last,
          surfaceColors: _selectedColors
              .map((k, v) => MapEntry(k.toString().split('.').last, v)),
          style: _analysisResult!.style,
        );

        variants.add(GeneratedVariant(
          imageData: imageData,
          colors: Map.from(_selectedColors),
          description: 'Variant ${i + 1}',
        ));
      }

      debugPrint('✅ Generated ${variants.length} variants successfully');
      setState(() {
        _variants = variants;
        _currentStep = '';
      });

      _navigateToMode(VisualizerMode.results);
      _resultsController.forward();

      final renderIds = <String>[];
      for (final v in variants) {
        final id = await PhotoLibraryService.savePhoto(
          imageData: v.imageData,
          description: v.description,
          metadata: {
            'source': 'visualizer_render',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        renderIds.add(id);
      }
      await JourneyService.instance.setArtifact('renderIds', renderIds);
      await JourneyService.instance.completeCurrentStep();
    } catch (e) {
      debugPrint('❌ Generation failed: $e');
      _showError('Failed to generate visualizations. Please try again.');
    }
  }

  Future<void> _generateMockup() async {
    // Implementation for mockup generation
    _navigateToMode(VisualizerMode.generate);
    // ... mockup generation logic
  }

  void _saveFavorite() {
    if (_variants.isEmpty) return;
    // Save current variant to favorites
    _showSuccess('Saved to your favorites!');
  }

  void _tryMoreColors() {
    // Return to surface selection screen
    _navigateToMode(VisualizerMode.selectSurfaces);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE74C3C),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF00B894),
      ),
    );
  }

  @override
  void dispose() {
    _stopDescriptiveActionRotation();
    _masterController.dispose();
    _breathingController.dispose();
    _progressController.dispose();
    _resultsController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // 🧠 SMART HELPER METHODS FOR ADAPTIVE UI

  String _getSpaceEmoji(SpaceType spaceType) {
    switch (spaceType) {
      case SpaceType.living:
        return '🛋️';
      case SpaceType.kitchen:
        return '🍳';
      case SpaceType.bathroom:
        return '🛁';
      case SpaceType.bedroom:
        return '🛏️';
      case SpaceType.exterior:
        return '🏠';
      case SpaceType.office:
        return '💼';
    }
  }

  String _getSpaceDescription(SpaceType spaceType) {
    switch (spaceType) {
      case SpaceType.living:
        return 'Living room detected with relaxation-focused surfaces';
      case SpaceType.kitchen:
        return 'Kitchen detected with cooking and storage surfaces';
      case SpaceType.bathroom:
        return 'Bathroom detected with moisture-resistant surfaces';
      case SpaceType.bedroom:
        return 'Bedroom detected with calming sleep-focused surfaces';
      case SpaceType.exterior:
        return 'Exterior detected with weather-resistant surfaces';
      case SpaceType.office:
        return 'Office detected with productivity-focused surfaces';
    }
  }

  String _getSurfaceInfo(SurfaceType surface, SpaceType spaceType) {
    switch (surface) {
      case SurfaceType.walls:
        return _getWallsInfo(spaceType);
      case SurfaceType.cabinets:
        return _getCabinetsInfo(spaceType);
      case SurfaceType.trim:
        return _getTrimInfo(spaceType);
      case SurfaceType.ceiling:
        return _getCeilingInfo(spaceType);
      case SurfaceType.shutters:
        return 'Exterior shutters - great for adding character and color contrast';
      case SurfaceType.doors:
        return 'Entry doors - make a bold first impression with color';
    }
  }

  String _getWallsInfo(SpaceType spaceType) {
    switch (spaceType) {
      case SpaceType.living:
        return 'Main focal area - sets the mood for relaxation and entertainment';
      case SpaceType.kitchen:
        return 'Backdrop for cooking - choose colors that energize and complement appliances';
      case SpaceType.bathroom:
        return 'Moisture-exposed area - select colors that feel fresh and clean';
      case SpaceType.bedroom:
        return 'Sleep sanctuary - opt for calming, restful colors';
      case SpaceType.exterior:
        return 'Curb appeal feature - weather-resistant colors that enhance architecture';
      case SpaceType.office:
        return 'Productivity zone - colors that promote focus and creativity';
    }
  }

  String _getCabinetsInfo(SpaceType spaceType) {
    if (spaceType == SpaceType.kitchen) {
      return 'Storage focal point - can dramatically change the kitchen\'s personality';
    } else {
      return 'Storage elements - accent colors that complement the main space';
    }
  }

  String _getTrimInfo(SpaceType spaceType) {
    return 'Architectural details - perfect for adding definition and elegance';
  }

  String _getCeilingInfo(SpaceType spaceType) {
    switch (spaceType) {
      case SpaceType.living:
        return 'Fifth wall opportunity - can make the room feel larger or cozier';
      case SpaceType.bedroom:
        return 'Overhead sanctuary - subtle colors that enhance sleep quality';
      case SpaceType.office:
        return 'Focus enhancer - colors that improve concentration and reduce eye strain';
      default:
        return 'Overhead surface - often overlooked but impactful design element';
    }
  }

  List<Map<String, String>> _getSmartColorSuggestions(SurfaceType surface, SpaceType spaceType) {
    // Get base colors for the surface type
    final baseColors = _getBaseSurfaceColors(surface);
    
    // Get space-specific modifications
    final spaceColors = _getSpaceSpecificColors(spaceType);
    
    // Combine and prioritize based on surface and space
    final smartSuggestions = <Map<String, String>>[];
    
    // Add space-appropriate colors first
    smartSuggestions.addAll(spaceColors);
    
    // Add surface-appropriate colors
    smartSuggestions.addAll(baseColors);
    
    // Remove duplicates and limit to 8 suggestions
    final seen = <String>{};
    return smartSuggestions.where((color) => seen.add(color['hex']!)).take(8).toList();
  }

  List<Map<String, String>> _getBaseSurfaceColors(SurfaceType surface) {
    switch (surface) {
      case SurfaceType.walls:
        return [
          {'hex': '#F8F9FA', 'name': 'Pure White'},
          {'hex': '#E9ECEF', 'name': 'Soft Gray'},
          {'hex': '#F5F5DC', 'name': 'Warm Beige'},
          {'hex': '#E6E6FA', 'name': 'Light Lavender'},
        ];
      case SurfaceType.cabinets:
        return [
          {'hex': '#FFFFFF', 'name': 'Classic White'},
          {'hex': '#2F4F4F', 'name': 'Dark Slate'},
          {'hex': '#8B4513', 'name': 'Rich Wood'},
          {'hex': '#483D8B', 'name': 'Navy Blue'},
        ];
      case SurfaceType.trim:
        return [
          {'hex': '#FFFFFF', 'name': 'Classic White'},
          {'hex': '#F5F5F5', 'name': 'Off White'},
          {'hex': '#000000', 'name': 'Bold Black'},
          {'hex': '#2F4F4F', 'name': 'Charcoal'},
        ];
      case SurfaceType.ceiling:
        return [
          {'hex': '#FFFFFF', 'name': 'Pure White'},
          {'hex': '#F8F8FF', 'name': 'Ghost White'},
          {'hex': '#F5F5DC', 'name': 'Cream'},
          {'hex': '#E6E6FA', 'name': 'Pale Lavender'},
        ];
      case SurfaceType.shutters:
        return [
          {'hex': '#000000', 'name': 'Classic Black'},
          {'hex': '#FFFFFF', 'name': 'Pure White'},
          {'hex': '#228B22', 'name': 'Forest Green'},
          {'hex': '#8B0000', 'name': 'Deep Red'},
        ];
      case SurfaceType.doors:
        return [
          {'hex': '#8B0000', 'name': 'Bold Red'},
          {'hex': '#000080', 'name': 'Navy Blue'},
          {'hex': '#000000', 'name': 'Classic Black'},
          {'hex': '#8B4513', 'name': 'Rich Brown'},
        ];
    }
  }

  List<Map<String, String>> _getSpaceSpecificColors(SpaceType spaceType) {
    switch (spaceType) {
      case SpaceType.living:
        return [
          {'hex': '#F5F5DC', 'name': 'Warm Beige'},
          {'hex': '#D2B48C', 'name': 'Tan'},
          {'hex': '#708090', 'name': 'Slate Gray'},
          {'hex': '#B8860B', 'name': 'Gold'},
        ];
      case SpaceType.kitchen:
        return [
          {'hex': '#FFFFFF', 'name': 'Fresh White'},
          {'hex': '#F0F8FF', 'name': 'Alice Blue'},
          {'hex': '#90EE90', 'name': 'Light Green'},
          {'hex': '#FFE4B5', 'name': 'Moccasin'},
        ];
      case SpaceType.bathroom:
        return [
          {'hex': '#E0FFFF', 'name': 'Light Cyan'},
          {'hex': '#F0F8FF', 'name': 'Alice Blue'},
          {'hex': '#E6E6FA', 'name': 'Lavender'},
          {'hex': '#F5FFFA', 'name': 'Mint Cream'},
        ];
      case SpaceType.bedroom:
        return [
          {'hex': '#E6E6FA', 'name': 'Lavender'},
          {'hex': '#F0F8FF', 'name': 'Alice Blue'},
          {'hex': '#F5DEB3', 'name': 'Wheat'},
          {'hex': '#FFEFD5', 'name': 'Papaya Whip'},
        ];
      case SpaceType.exterior:
        return [
          {'hex': '#F5F5DC', 'name': 'Beige'},
          {'hex': '#D2B48C', 'name': 'Tan'},
          {'hex': '#A0522D', 'name': 'Sienna'},
          {'hex': '#8FBC8F', 'name': 'Dark Sea Green'},
        ];
      case SpaceType.office:
        return [
          {'hex': '#F8F8FF', 'name': 'Ghost White'},
          {'hex': '#E6E6FA', 'name': 'Lavender'},
          {'hex': '#D3D3D3', 'name': 'Light Gray'},
          {'hex': '#B0C4DE', 'name': 'Light Steel Blue'},
        ];
    }
  }

  String _getSurfaceColorAdvice(SurfaceType surface, SpaceType spaceType) {
    switch (surface) {
      case SurfaceType.walls:
        return _getWallColorAdvice(spaceType);
      case SurfaceType.cabinets:
        return _getCabinetColorAdvice(spaceType);
      case SurfaceType.trim:
        return 'defining architectural features and adding elegance';
      case SurfaceType.ceiling:
        return 'creating height and atmosphere overhead';
      case SurfaceType.shutters:
        return 'adding curb appeal and architectural interest';
      case SurfaceType.doors:
        return 'making a bold entrance statement';
    }
  }

  String _getWallColorAdvice(SpaceType spaceType) {
    switch (spaceType) {
      case SpaceType.living:
        return 'creating a welcoming, relaxing atmosphere';
      case SpaceType.kitchen:
        return 'energizing cooking activities and complementing appliances';
      case SpaceType.bathroom:
        return 'creating a spa-like, refreshing environment';
      case SpaceType.bedroom:
        return 'promoting restful sleep and tranquility';
      case SpaceType.exterior:
        return 'enhancing curb appeal and architectural style';
      case SpaceType.office:
        return 'boosting productivity and mental clarity';
    }
  }

  String _getCabinetColorAdvice(SpaceType spaceType) {
    if (spaceType == SpaceType.kitchen) {
      return 'transforming the kitchen\'s personality and storage appeal';
    } else {
      return 'complementing the space while highlighting storage';
    }
  }

  IconData _getLightingIcon(String lighting) {
    switch (lighting.toLowerCase()) {
      case 'natural':
        return Icons.wb_sunny;
      case 'artificial':
        return Icons.lightbulb;
      case 'mixed':
        return Icons.lightbulb_outline;
      default:
        return Icons.light_mode;
    }
  }

  Color _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }
}

// 📊 DATA MODELS
class GeneratedVariant {
  final Uint8List imageData;
  final Map<SurfaceType, String> colors;
  final String description;

  GeneratedVariant({
    required this.imageData,
    required this.colors,
    required this.description,
  });
}
