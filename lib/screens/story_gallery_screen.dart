import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/story_experience.dart';
import '../services/story_engine.dart';
import 'story_player_screen.dart';

class StoryGalleryScreen extends StatefulWidget {
  final String userId;

  const StoryGalleryScreen({
    super.key,
    required this.userId,
  });

  @override
  State<StoryGalleryScreen> createState() => _StoryGalleryScreenState();
}

class _StoryGalleryScreenState extends State<StoryGalleryScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroController;
  late Animation<double> _heroAnimation;

  final StoryEngine _storyEngine = StoryEngine();
  List<StoryExperience> _experiences = [];
  bool _isLoading = true;
  String _selectedMoodFilter = 'all';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserExperiences();
  }

  void _initializeAnimations() {
    _heroController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _heroAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeOut),
    );

    _heroController.forward();
  }

  void _loadUserExperiences() {
    _storyEngine.getUserStoryExperiences(widget.userId).listen((experiences) {
      if (mounted) {
        setState(() {
          _experiences = experiences;
          _isLoading = false;
        });
      }
    });
  }

  List<StoryExperience> get _filteredExperiences {
    if (_selectedMoodFilter == 'all') return _experiences;
    return _experiences
        .where((exp) => exp.mood.name == _selectedMoodFilter)
        .toList();
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildHeroSection(),
          _buildMoodFilters(),
          _buildExperienceGrid(),
          if (_isLoading) _buildLoadingSection(),
          if (!_isLoading && _experiences.isEmpty) _buildEmptyState(),
        ],
      ),
      floatingActionButton: _buildCreateStoryFAB(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      title: const Text(
        'Color Stories',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _showInfoDialog,
          icon: const Icon(Icons.info_outline, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _heroAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 50 * (1 - _heroAnimation.value)),
            child: Opacity(
              opacity: _heroAnimation.value,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                      Color(0xFFEC4899),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Immersive Color Journeys',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Transform your palettes into personalized stories that guide you through the psychology, application, and magic of color design.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _buildFeatureChip('🎨 Interactive', Icons.touch_app),
                        const SizedBox(width: 12),
                        _buildFeatureChip('🎵 Audio Guided', Icons.headphones),
                      ],
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

  Widget _buildFeatureChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
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

  Widget _buildMoodFilters() {
    final moods = [
      'all',
      'serene',
      'energetic',
      'sophisticated',
      'cozy',
      'fresh'
    ];

    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: moods.length,
          itemBuilder: (context, index) {
            final mood = moods[index];
            final isSelected = _selectedMoodFilter == mood;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedMoodFilter = mood;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  mood == 'all' ? 'All Stories' : mood.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExperienceGrid() {
    final experiences = _filteredExperiences;

    if (experiences.isEmpty && !_isLoading) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildExperienceCard(experiences[index], index);
          },
          childCount: experiences.length,
        ),
      ),
    );
  }

  Widget _buildExperienceCard(StoryExperience experience, int index) {
    final delay = Duration(milliseconds: 100 * index);

    return FutureBuilder<Widget>(
      future: Future.delayed(delay, () => _createCard(experience)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
          );
        }
        return snapshot.data!;
      },
    );
  }

  Widget _createCard(StoryExperience experience) {
    final moodColors = _getMoodColors(experience.mood);

    return GestureDetector(
      onTap: () => _launchStoryExperience(experience),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: moodColors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: moodColors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _StoryPatternPainter(experience.mood),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress indicator
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: experience.completionProgress,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${experience.completionPercentage}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Mood icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _getMoodIcon(experience.mood),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),

                  const Spacer(),

                  // Title
                  Text(
                    experience.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Duration and chapters
                  Text(
                    '${experience.chapters.length} chapters • ${experience.totalDuration.inMinutes}min',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Play button
                  Container(
                    width: double.infinity,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          experience.isCompleted
                              ? Icons.replay
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          experience.isCompleted ? 'Replay' : 'Continue',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  Widget _buildLoadingSection() {
    return SliverToBoxAdapter(
      child: Container(
        height: 200,
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.auto_stories,
              color: Colors.white.withValues(alpha: 0.6),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Color Stories Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first immersive color story from any palette to begin your journey.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateStoryFAB() {
    return FloatingActionButton.extended(
      onPressed: _showCreateStoryDialog,
      backgroundColor: const Color(0xFF6366F1),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Create Story',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _launchStoryExperience(StoryExperience experience) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            StoryPlayerScreen(storyExperience: experience),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showCreateStoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Create New Story',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'To create a new color story, first create a color palette in the main app, then return here to generate your personalized immersive experience.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to main app
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Go to Palettes',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'About Color Stories',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Color Stories transform your palettes into immersive, educational experiences that guide you through:',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              SizedBox(height: 12),
              Text('• Color psychology and emotional impact'),
              Text('• Professional application techniques'),
              Text('• Room-specific design guidance'),
              Text('• Interactive learning elements'),
              Text('• Personalized narrative experiences'),
              SizedBox(height: 12),
              Text(
                'Each story is generated specifically for your chosen palette and design preferences, creating a unique journey every time.',
                style: TextStyle(
                    fontSize: 14, height: 1.5, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Got It', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<Color> _getMoodColors(StoryMood mood) {
    switch (mood) {
      case StoryMood.serene:
        return [const Color(0xFF3B82F6), const Color(0xFF1E40AF)];
      case StoryMood.energetic:
        return [const Color(0xFFEF4444), const Color(0xFFDC2626)];
      case StoryMood.sophisticated:
        return [const Color(0xFF6366F1), const Color(0xFF4F46E5)];
      case StoryMood.cozy:
        return [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      case StoryMood.fresh:
        return [const Color(0xFF10B981), const Color(0xFF059669)];
      case StoryMood.dramatic:
        return [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)];
      case StoryMood.natural:
        return [const Color(0xFF84CC16), const Color(0xFF65A30D)];
      case StoryMood.playful:
        return [const Color(0xFFEC4899), const Color(0xFFDB2777)];
      case StoryMood.minimalist:
        return [const Color(0xFF6B7280), const Color(0xFF4B5563)];
      case StoryMood.luxurious:
        return [const Color(0xFF7C2D12), const Color(0xFF92400E)];
    }
  }

  IconData _getMoodIcon(StoryMood mood) {
    switch (mood) {
      case StoryMood.serene:
        return Icons.waves;
      case StoryMood.energetic:
        return Icons.flash_on;
      case StoryMood.sophisticated:
        return Icons.diamond;
      case StoryMood.cozy:
        return Icons.fireplace;
      case StoryMood.fresh:
        return Icons.air;
      case StoryMood.dramatic:
        return Icons.theater_comedy;
      case StoryMood.natural:
        return Icons.eco;
      case StoryMood.playful:
        return Icons.toys;
      case StoryMood.minimalist:
        return Icons.minimize;
      case StoryMood.luxurious:
        return Icons.star;
    }
  }
}

class _StoryPatternPainter extends CustomPainter {
  final StoryMood mood;

  _StoryPatternPainter(this.mood);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw subtle background pattern based on mood
    switch (mood) {
      case StoryMood.serene:
        _drawWavePattern(canvas, size, paint);
        break;
      case StoryMood.energetic:
        _drawBoltPattern(canvas, size, paint);
        break;
      case StoryMood.sophisticated:
        _drawGeometricPattern(canvas, size, paint);
        break;
      default:
        _drawCirclePattern(canvas, size, paint);
    }
  }

  void _drawWavePattern(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 3; i++) {
      final y = size.height * (0.3 + i * 0.2);
      path.moveTo(0, y);
      path.quadraticBezierTo(size.width * 0.5, y - 20, size.width, y);
    }
    canvas.drawPath(path, paint);
  }

  void _drawBoltPattern(Canvas canvas, Size size, Paint paint) {
    for (int i = 0; i < 4; i++) {
      final x = size.width * (0.2 + i * 0.2);
      canvas.drawLine(Offset(x, 0), Offset(x + 10, size.height * 0.3), paint);
      canvas.drawLine(Offset(x + 10, size.height * 0.3),
          Offset(x - 5, size.height * 0.7), paint);
      canvas.drawLine(
          Offset(x - 5, size.height * 0.7), Offset(x + 5, size.height), paint);
    }
  }

  void _drawGeometricPattern(Canvas canvas, Size size, Paint paint) {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        final rect = Rect.fromLTWH(
          size.width * (0.2 + i * 0.3),
          size.height * (0.2 + j * 0.3),
          20,
          20,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  void _drawCirclePattern(Canvas canvas, Size size, Paint paint) {
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * (0.1 + i * 0.2), size.height * 0.5),
        8,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
