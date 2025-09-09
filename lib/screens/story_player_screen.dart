import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/story_experience.dart';
import '../services/story_engine.dart';

class StoryPlayerScreen extends StatefulWidget {
  final StoryExperience storyExperience;

  const StoryPlayerScreen({
    super.key,
    required this.storyExperience,
  });

  @override
  State<StoryPlayerScreen> createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends State<StoryPlayerScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _colorRevealController;
  late AnimationController _particleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _colorRevealAnimation;

  Timer? _progressTimer;
  Timer? _autoAdvanceTimer;

  int _currentChapterIndex = 0;
  double _chapterProgress = 0.0;
  bool _isPlaying = false;
  bool _isInteractiveElementVisible = false;
  InteractiveElement? _currentInteractiveElement;

  final StoryEngine _storyEngine = StoryEngine();
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _findCurrentChapter();
    _startStoryPlayback();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _colorRevealController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _colorRevealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _colorRevealController, curve: Curves.elasticOut),
    );
  }

  void _findCurrentChapter() {
    // Find the first uncompleted chapter or start from beginning
    for (int i = 0; i < widget.storyExperience.chapters.length; i++) {
      if (!widget.storyExperience
          .isChapterCompleted(widget.storyExperience.chapters[i].id)) {
        _currentChapterIndex = i;
        break;
      }
    }
  }

  void _startStoryPlayback() {
    setState(() {
      _isPlaying = true;
    });

    _fadeController.forward();
    _slideController.forward();

    // Start progress timer
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isPlaying && mounted) {
        setState(() {
          _chapterProgress += 0.1 / _currentChapter.duration.inSeconds;
          if (_chapterProgress >= 1.0) {
            _chapterProgress = 1.0;
            _completeCurrentChapter();
          }
        });

        // Check for interactive elements
        _checkForInteractiveElements();
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
        _showInteractiveElement(element);
        break;
      }
    }
  }

  void _showInteractiveElement(InteractiveElement element) {
    setState(() {
      _currentInteractiveElement = element;
      _isInteractiveElementVisible = true;
    });

    // Pause story if it's an interactive element that requires user input
    if (element.type == 'mood_selector' ||
        element.type == 'room_transformation') {
      _pauseStory();
    }

    // Trigger appropriate animation based on element type
    switch (element.type) {
      case 'color_reveal':
        _colorRevealController.forward();
        HapticFeedback.lightImpact();
        break;
      case 'room_transformation':
        _particleController.forward();
        break;
    }
  }

  void _completeInteractiveElement() {
    if (_currentInteractiveElement != null) {
      setState(() {
        _currentInteractiveElement =
            _currentInteractiveElement!.copyWith(isCompleted: true);
        _isInteractiveElementVisible = false;
      });

      // Resume story if it was paused
      if (!_isPlaying) {
        _resumeStory();
      }
    }
  }

  void _completeCurrentChapter() {
    _pauseStory();

    // Update progress in Firebase
    _storyEngine.updateStoryProgress(
      experienceId: widget.storyExperience.id,
      chapterId: _currentChapter.id,
      progress: 1.0,
      analyticsData: {
        'completed_at': DateTime.now().toIso8601String(),
        'interaction_count': _currentChapter.interactiveElements.length,
      },
    );

    // Move to next chapter if available
    if (_currentChapterIndex < widget.storyExperience.chapters.length - 1) {
      _autoAdvanceTimer = Timer(const Duration(seconds: 2), () {
        _moveToNextChapter();
      });
    } else {
      _completeStory();
    }
  }

  void _moveToNextChapter() {
    if (_currentChapterIndex < widget.storyExperience.chapters.length - 1) {
      setState(() {
        _currentChapterIndex++;
        _chapterProgress = 0.0;
      });

      // Reset animations
      _fadeController.reset();
      _slideController.reset();
      _colorRevealController.reset();

      // Animate to next chapter
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      _startStoryPlayback();
    }
  }

  void _completeStory() {
    // Update final progress
    _storyEngine.updateStoryProgress(
      experienceId: widget.storyExperience.id,
      chapterId: _currentChapter.id,
      progress: 1.0,
      analyticsData: {
        'story_completed_at': DateTime.now().toIso8601String(),
        'total_duration': widget.storyExperience.totalDuration.inMinutes,
      },
    );

    // Show completion celebration
    _showCompletionDialog();
  }

  void _pauseStory() {
    setState(() {
      _isPlaying = false;
    });
    _progressTimer?.cancel();
  }

  void _resumeStory() {
    setState(() {
      _isPlaying = true;
    });
    _startStoryPlayback();
  }

  StoryChapter get _currentChapter =>
      widget.storyExperience.chapters[_currentChapterIndex];

  @override
  void dispose() {
    _progressTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _colorRevealController.dispose();
    _particleController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient based on current chapter
          _buildAnimatedBackground(),

          // Main story content
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.storyExperience.chapters.length,
            itemBuilder: (context, index) {
              return _buildChapterView(widget.storyExperience.chapters[index]);
            },
          ),

          // Interactive overlay
          if (_isInteractiveElementVisible &&
              _currentInteractiveElement != null)
            _buildInteractiveOverlay(),

          // Story controls
          _buildStoryControls(),

          // Progress indicator
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    final colors = _currentChapter.revealedColors.isNotEmpty
        ? _currentChapter.revealedColors
            .take(2)
            .map((hex) => Color(int.parse(hex.replaceAll('#', '0xFF')))
                .withValues(alpha: 0.3))
            .toList()
        : [
            Colors.indigo.withValues(alpha: 0.3),
            Colors.purple.withValues(alpha: 0.3)
          ];

    return AnimatedBuilder(
      animation: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.length >= 2 ? colors : [colors.first, colors.first],
          ),
        ),
      ),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: child,
        );
      },
    );
  }

  Widget _buildChapterView(StoryChapter chapter) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60), // Space for controls

            // Chapter title
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  chapter.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Chapter content
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    child: Text(
                      chapter.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.6,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Color reveals
            if (chapter.revealedColors.isNotEmpty)
              _buildColorRevealSection(chapter.revealedColors),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRevealSection(List<String> colors) {
    return AnimatedBuilder(
      animation: _colorRevealAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _colorRevealAnimation.value,
          child: Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: colors.take(4).map((hex) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Color(int.parse(hex.replaceAll('#', '0xFF'))),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInteractiveOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentInteractiveElement!.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _currentInteractiveElement!.description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Interactive element content based on type
                _buildInteractiveContent(_currentInteractiveElement!),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _completeInteractiveElement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveContent(InteractiveElement element) {
    switch (element.type) {
      case 'color_reveal':
        final colorData = element.data;
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Color(int.parse(colorData['color'].replaceAll('#', '0xFF'))),
            borderRadius: BorderRadius.circular(60),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              colorData['name'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );

      case 'mood_selector':
        final options = List<String>.from(element.data['options'] ?? []);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            return ElevatedButton(
              onPressed: () {
                // Handle mood selection
                HapticFeedback.selectionClick();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(option),
            );
          }).toList(),
        );

      default:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Interactive content',
            style: TextStyle(color: Colors.black54),
          ),
        );
    }
  }

  Widget _buildStoryControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
              const Spacer(),
              IconButton(
                onPressed: _isPlaying ? _pauseStory : _resumeStory,
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _currentChapterIndex <
                        widget.storyExperience.chapters.length - 1
                    ? _moveToNextChapter
                    : null,
                icon:
                    const Icon(Icons.skip_next, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final totalProgress = (_currentChapterIndex + _chapterProgress) /
        widget.storyExperience.chapters.length;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chapter progress
              LinearProgressIndicator(
                value: _chapterProgress,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 3,
              ),
              const SizedBox(height: 8),

              // Overall progress
              Row(
                children: [
                  Text(
                    'Chapter ${_currentChapterIndex + 1} of ${widget.storyExperience.chapters.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(totalProgress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '🎉 Story Complete!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Congratulations! You\'ve completed your color story journey.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Your palette is now ready to transform your ${widget.storyExperience.sourceColorStoryId != null ? 'space' : 'room'}!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Continue to Palette',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
