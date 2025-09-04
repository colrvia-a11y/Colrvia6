import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/story_experience.dart';
import '../models/immersive_story_context.dart';
import '../widgets/story_sharing_widget.dart';

/// Revolutionary immersive color story player with cinematic experience
class ImmersiveStoryPlayerScreen extends StatefulWidget {
  final StoryExperience storyExperience;
  final ColorStoryContext? context;

  const ImmersiveStoryPlayerScreen({
    super.key,
    required this.storyExperience,
    this.context,
  });

  @override
  State<ImmersiveStoryPlayerScreen> createState() =>
      _ImmersiveStoryPlayerScreenState();
}

class _ImmersiveStoryPlayerScreenState extends State<ImmersiveStoryPlayerScreen>
    with TickerProviderStateMixin {
  // Animation controllers for cinematic effects
  late AnimationController _cinematicController;
  late AnimationController _parallaxController;
  late AnimationController _colorBloomController;
  late AnimationController _particleController;
  late AnimationController _breathingController;
  late AnimationController _heartbeatController;

  // Cinematic animations
  late Animation<double> _cinematicFade;
  late Animation<Offset> _parallaxDrift;
  late Animation<double> _colorBloom;
  late Animation<double> _particleFloat;
  late Animation<double> _breathingPulse;
  late Animation<double> _heartbeatSync;

  // Story state
  int _currentChapterIndex = 0;
  double _chapterProgress = 0.0;
  bool _isPlaying = false;
  bool _isImmersiveMode = true;
  Timer? _progressTimer;
  Timer? _narrativeTimer;

  // Interactive elements
  InteractiveElement? _currentInteractiveElement;
  bool _isInteractionActive = false;

  // Visual effects state
  List<Particle> _particles = [];
  Color _dominantColor = Colors.blue;
  Color _accentColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _initializeCinematicAnimations();
    _analyzeStoryColors();
    _startImmersiveExperience();
  }

  void _initializeCinematicAnimations() {
    // Cinematic fade for dramatic transitions
    _cinematicController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Parallax for depth and immersion
    _parallaxController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    // Color bloom for emotional moments
    _colorBloomController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Particle system for magical effects
    _particleController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    // Breathing effect for meditation moments
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    // Heartbeat sync for emotional connection
    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create animations
    _cinematicFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cinematicController, curve: Curves.easeInOut),
    );

    _parallaxDrift = Tween<Offset>(
      begin: const Offset(-0.1, 0.0),
      end: const Offset(0.1, 0.0),
    ).animate(
        CurvedAnimation(parent: _parallaxController, curve: Curves.easeInOut));

    _colorBloom = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _colorBloomController, curve: Curves.elasticOut),
    );

    _particleFloat = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.linear),
    );

    _breathingPulse = Tween<double>(begin: 0.8, end: 1.1).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _heartbeatSync = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut),
    );

    // Start continuous animations
    _parallaxController.repeat(reverse: true);
    _particleController.repeat();
    _breathingController.repeat(reverse: true);
  }

  void _analyzeStoryColors() {
    if (widget.context != null && widget.context!.palette.isNotEmpty) {
      _dominantColor = widget.context!.palette.first;
      _accentColor = widget.context!.palette.length > 1
          ? widget.context!.palette[1]
          : _dominantColor.withValues(alpha: 0.7);
    } else if (widget.storyExperience.chapters.isNotEmpty) {
      final chapter = widget.storyExperience.chapters.first;
      if (chapter.revealedColors.isNotEmpty) {
        _dominantColor = _parseColor(chapter.revealedColors.first);
      }
    }

    // IMPORTANT: Generating particles uses MediaQuery for screen size.
    // Accessing MediaQuery during initState triggers a Flutter error
    // (dependOnInheritedWidgetOfExactType before init completed).
    // Defer particle generation until after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _generateParticles();
      setState(() {});
    });
  }

  void _generateParticles() {
    final random = Random();
    _particles = List.generate(20, (index) {
      return Particle(
        position: Offset(
          random.nextDouble() * MediaQuery.of(context).size.width,
          random.nextDouble() * MediaQuery.of(context).size.height,
        ),
        color: _dominantColor.withValues(alpha: random.nextDouble() * 0.3),
        size: random.nextDouble() * 4 + 2,
        velocity: Offset(
          (random.nextDouble() - 0.5) * 0.5,
          (random.nextDouble() - 0.5) * 0.5,
        ),
      );
    });
  }

  void _startImmersiveExperience() {
    setState(() {
      _isPlaying = true;
    });

    // Start with dramatic entrance
    _cinematicController.forward();

    // Begin story progression
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isPlaying && mounted) {
        setState(() {
          _chapterProgress += 0.1 / _currentChapter.duration.inSeconds;
          if (_chapterProgress >= 1.0) {
            _completeChapter();
          }
        });

        _checkForInteractiveElements();
        _updateVisualEffects();
      }
    });
  }

  void _checkForInteractiveElements() {
    final currentTime = Duration(
      milliseconds:
          (_chapterProgress * _currentChapter.duration.inMilliseconds).round(),
    );

    for (final element in _currentChapter.interactiveElements) {
      if (!element.isCompleted &&
          currentTime >= element.timestamp &&
          _currentInteractiveElement?.id != element.id) {
        _triggerInteractiveElement(element);
        break;
      }
    }
  }

  void _triggerInteractiveElement(InteractiveElement element) {
    setState(() {
      _currentInteractiveElement = element;
      _isInteractionActive = true;
    });

    // Trigger appropriate animations based on element type
    switch (element.type) {
      case 'color_breathing':
        _startBreathingExperience();
        break;
      case 'light_simulation':
        _simulateLightChanges();
        break;
      case 'color_personality':
        _revealColorPersonality();
        break;
      default:
        _colorBloomController.forward();
    }

    HapticFeedback.mediumImpact();
  }

  void _startBreathingExperience() {
    // Enhanced breathing meditation with colors
    _breathingController.repeat(reverse: true);
    _heartbeatController.repeat(reverse: true);

    // Show breathing guidance overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildBreathingOverlay(),
    );
  }

  void _simulateLightChanges() {
    // Animate through different lighting conditions
    final lightStages = ['dawn', 'morning', 'midday', 'evening'];
    int currentStage = 0;

    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (currentStage < lightStages.length) {
        // Update visual state for light simulation
        _colorBloomController
            .forward()
            .then((_) => _colorBloomController.reset());
        currentStage++;
      } else {
        timer.cancel();
        _dismissInteraction();
      }
    });
  }

  void _revealColorPersonality() {
    // Show personality analysis with animated reveal
    showDialog(
      context: context,
      builder: (context) => _buildColorPersonalityDialog(),
    );
  }

  void _updateVisualEffects() {
    // Update particle positions
    for (var particle in _particles) {
      particle.position = Offset(
        particle.position.dx + particle.velocity.dx,
        particle.position.dy + particle.velocity.dy,
      );

      // Wrap around screen edges
      if (particle.position.dx < 0) {
        particle.position =
            Offset(MediaQuery.of(context).size.width, particle.position.dy);
      }
      if (particle.position.dx > MediaQuery.of(context).size.width) {
        particle.position = Offset(0, particle.position.dy);
      }
      if (particle.position.dy < 0) {
        particle.position =
            Offset(particle.position.dx, MediaQuery.of(context).size.height);
      }
      if (particle.position.dy > MediaQuery.of(context).size.height) {
        particle.position = Offset(particle.position.dx, 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with cinematic gradient
          _buildCinematicBackground(),

          // Particle system overlay
          if (_isImmersiveMode) _buildParticleSystem(),

          // Parallax content layers
          _buildParallaxContent(),

          // Story content with gestures
          _buildStoryContent(),

          // Interactive overlays
          if (_isInteractionActive) _buildInteractiveOverlay(),

          // Immersive controls
          _buildImmersiveControls(),
        ],
      ),
    );
  }

  Widget _buildCinematicBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([_cinematicFade, _colorBloom]),
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5 + (_colorBloom.value * 0.5),
              colors: [
                _dominantColor.withValues(alpha: 0.3 * _cinematicFade.value),
                _accentColor.withValues(alpha: 0.1 * _cinematicFade.value),
                Colors.black.withValues(alpha: 0.8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticleSystem() {
    return AnimatedBuilder(
      animation: _particleFloat,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(_particles, _particleFloat.value),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }

  Widget _buildParallaxContent() {
    return AnimatedBuilder(
      animation: _parallaxDrift,
      builder: (context, child) {
        return Transform.translate(
          offset: _parallaxDrift.value * 20,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _dominantColor.withValues(alpha: 0.1),
                  _accentColor.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoryContent() {
    return SafeArea(
      child: AnimatedBuilder(
        animation: _cinematicFade,
        builder: (context, child) {
          return Opacity(
            opacity: _cinematicFade.value,
            child: GestureDetector(
              onTap: _togglePlayPause,
              onHorizontalDragEnd: (details) {
                if (details.velocity.pixelsPerSecond.dx > 300) {
                  _previousChapter();
                } else if (details.velocity.pixelsPerSecond.dx < -300) {
                  _nextChapter();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chapter title with animation
                    AnimatedBuilder(
                      animation: _breathingPulse,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _breathingPulse.value,
                          child: Text(
                            _currentChapter.title,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: _dominantColor,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Story content with immersive typography
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _currentChapter.content,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.8,
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),

                    // Progress indicator with color animation
                    Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _chapterProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              colors: [_dominantColor, _accentColor],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInteractiveOverlay() {
    if (_currentInteractiveElement == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _colorBloom,
      builder: (context, child) {
        return Container(
          color: Colors.black.withValues(alpha: 0.8 * _colorBloom.value),
          child: Center(
            child: Transform.scale(
              scale: _colorBloom.value,
              child: Container(
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _dominantColor.withValues(alpha: 0.3),
                      _accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _dominantColor, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentInteractiveElement!.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentInteractiveElement!.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _dismissInteraction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _dominantColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreathingOverlay() {
    return AnimatedBuilder(
      animation: Listenable.merge([_breathingPulse, _heartbeatSync]),
      builder: (context, child) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Breathing circle with color pulse
                Transform.scale(
                  scale: _breathingPulse.value * _heartbeatSync.value,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _dominantColor.withValues(alpha: 0.8),
                          _accentColor.withValues(alpha: 0.4),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _dominantColor,
                          blurRadius: 20 * _breathingPulse.value,
                          spreadRadius: 5 * _breathingPulse.value,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Breathe',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Feel your colors breathe with you.\nLet their energy flow through your space.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _dismissInteraction();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dominantColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text('Continue Journey'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorPersonalityDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _dominantColor.withValues(alpha: 0.9),
              _accentColor.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your Color Personality',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _dominantColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _dominantColor.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your ${_getColorName(_dominantColor)} choice reflects your need for ${_getColorEmotion(_dominantColor)}. This color speaks to your soul because it represents your journey toward inner ${_getColorGoal(_dominantColor)}.',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _dismissInteraction();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _dominantColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text('Continue Story'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImmersiveControls() {
    return Positioned(
      top: 60,
      right: 20,
      child: Column(
        children: [
          // Immersive mode toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _isImmersiveMode = !_isImmersiveMode;
                });
              },
              icon: Icon(
                _isImmersiveMode ? Icons.visibility_off : Icons.visibility,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Exit button
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  StoryChapter get _currentChapter =>
      widget.storyExperience.chapters[_currentChapterIndex];

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    HapticFeedback.lightImpact();
  }

  void _nextChapter() {
    if (_currentChapterIndex < widget.storyExperience.chapters.length - 1) {
      setState(() {
        _currentChapterIndex++;
        _chapterProgress = 0.0;
      });
      _cinematicController.forward(from: 0);
    }
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      setState(() {
        _currentChapterIndex--;
        _chapterProgress = 0.0;
      });
      _cinematicController.forward(from: 0);
    }
  }

  void _completeChapter() {
    if (_currentChapterIndex < widget.storyExperience.chapters.length - 1) {
      _nextChapter();
    } else {
      // Story completed
      _showCompletionCelebration();
    }
  }

  void _showCompletionCelebration() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_dominantColor, _accentColor],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🎉 Story Complete! 🎉',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'You\'ve completed your immersive color journey. These colors are now part of your story.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showShareDialog();
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share Story'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _dominantColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareDialog() {
    showDialog(
      context: context,
      builder: (context) => ShareStoryDialog(
        story: widget.storyExperience,
        context: widget.context,
      ),
    );
  }

  void _dismissInteraction() {
    setState(() {
      _isInteractionActive = false;
      _currentInteractiveElement = null;
    });
    _colorBloomController.reset();
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  String _getColorName(Color color) {
    final hsl = HSLColor.fromColor(color);
    final hue = hsl.hue;

    if (hue < 30) return 'Red';
    if (hue < 60) return 'Orange';
    if (hue < 90) return 'Yellow';
    if (hue < 150) return 'Green';
    if (hue < 210) return 'Blue';
    if (hue < 270) return 'Purple';
    if (hue < 330) return 'Pink';
    return 'Red';
  }

  String _getColorEmotion(Color color) {
    final name = _getColorName(color).toLowerCase();
    final emotions = {
      'red': 'passion and energy',
      'orange': 'warmth and enthusiasm',
      'yellow': 'joy and creativity',
      'green': 'balance and growth',
      'blue': 'peace and clarity',
      'purple': 'wisdom and spirituality',
      'pink': 'love and compassion',
    };
    return emotions[name] ?? 'harmony';
  }

  String _getColorGoal(Color color) {
    final name = _getColorName(color).toLowerCase();
    final goals = {
      'red': 'vitality',
      'orange': 'connection',
      'yellow': 'illumination',
      'green': 'renewal',
      'blue': 'serenity',
      'purple': 'transformation',
      'pink': 'acceptance',
    };
    return goals[name] ?? 'balance';
  }

  @override
  void dispose() {
    _cinematicController.dispose();
    _parallaxController.dispose();
    _colorBloomController.dispose();
    _particleController.dispose();
    _breathingController.dispose();
    _heartbeatController.dispose();
    _progressTimer?.cancel();
    _narrativeTimer?.cancel();
    super.dispose();
  }
}

/// Particle class for magical visual effects
class Particle {
  Offset position;
  final Color color;
  final double size;
  final Offset velocity;

  Particle({
    required this.position,
    required this.color,
    required this.size,
    required this.velocity,
  });
}

/// Custom painter for particle system
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animation;

  ParticlePainter(this.particles, this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withValues(alpha: 0.6 * (1 - animation % 1))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        particle.position,
        particle.size * (1 + animation * 0.2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
