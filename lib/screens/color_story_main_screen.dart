import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:color_canvas/screens/story_gallery_screen.dart';
import 'package:color_canvas/screens/immersive_story_player_screen.dart';
import 'package:color_canvas/models/story_experience.dart';
import 'package:color_canvas/models/immersive_story_context.dart';
import 'package:color_canvas/services/immersive_narrative_engine.dart';

class ColorStoryMainScreen extends StatefulWidget {
  const ColorStoryMainScreen({super.key});

  @override
  State<ColorStoryMainScreen> createState() => _ColorStoryMainScreenState();
}

class _ColorStoryMainScreenState extends State<ColorStoryMainScreen> with TickerProviderStateMixin {
  // Brand colors matching visualizer and theme
  static const Color _forestGreen = Color(0xFF404934);      // Primary brand green
  static const Color _peachGradient = Color(0xFFE5A177);    // Deeper peach for gradients
  Color get _brandPeach => Theme.of(context).colorScheme.secondary;
  static const Color _deepForest = Color(0xFF2F3728);       // Deeper forest green
  static const Color _warmWhite = Color(0xFFFAFAFA);        // Brand white/cream
  static const Color _warmWhite90 = Color.fromRGBO(250, 250, 250, 0.9);
  static const Color _warmWhite80 = Color.fromRGBO(250, 250, 250, 0.8);
  static const Color _darkText = Color(0xFF1C1C1C);         // Main text color
  static const Color _brownAccent = Color(0xFFD8936B);      // From visualizer palette
  static const Color _sageGreen = Color(0xFF6B7A5A);        // From visualizer palette
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  
  // State
  bool _isLoading = false;
  List<StoryExperience> _recentStories = [];
  List<StoryExperience> _featuredStories = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadStoryData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

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

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStoryData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // In a real app, we'd load user's stories from Firestore
        // For now, we'll create some sample data
        _recentStories = [];
        _featuredStories = [];
      }
    } catch (e) {
      // Handle error silently for now
    } finally {
      setState(() => _isLoading = false);
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
              _warmWhite,
              _forestGreen.withValues(alpha: 0.03),
              _brandPeach.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildHeroAppBar(),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeSection(),
                          const SizedBox(height: 32),
                          _buildQuickActions(),
                          const SizedBox(height: 32),
                          _buildFeaturedSection(),
                          const SizedBox(height: 32),
                          _buildRecentSection(),
                          const SizedBox(height: 100), // Bottom padding for nav
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _forestGreen,
              _deepForest,
            ],
          ),
        ),
        child: FlexibleSpaceBar(
          title: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_stories,
                      color: _warmWhite,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Color Stories',
                      style: TextStyle(
                        color: _warmWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          centerTitle: true,
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _forestGreen,
                  _deepForest,
                ],
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40), // Account for status bar
                  Icon(
                    Icons.auto_stories,
                    size: 60,
                    color: _warmWhite90,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Immersive Color Experiences',
                    style: TextStyle(
                      color: _warmWhite80,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final user = FirebaseAuth.instance.currentUser;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _warmWhite,
            _forestGreen.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _forestGreen.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user != null ? 'Welcome back!' : 'Welcome to Color Stories',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Transform your color palettes into immersive, personalized experiences. Explore the psychology, emotions, and stories behind every hue.',
            style: TextStyle(
              fontSize: 16,
              color: _darkText.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [_brandPeach, _peachGradient],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: _brandPeach.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _createImmersiveStory,
              icon: const Icon(Icons.auto_awesome, color: Colors.white),
              label: const Text(
                'Discover Your Color Story',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _darkText,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.auto_awesome,
                title: 'Immersive Story',
                subtitle: 'AI-powered journey',
                color: _peachGradient,
                onTap: _createImmersiveStory,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                icon: Icons.library_books,
                title: 'My Stories',
                subtitle: 'Browse collection',
                color: _brandPeach,
                onTap: _viewMyStories,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.explore,
                title: 'Discover',
                subtitle: 'Featured stories',
                color: _brownAccent,
                onTap: _exploreStories,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                icon: Icons.psychology,
                title: 'Learn',
                subtitle: 'Color psychology',
                color: _sageGreen,
                onTap: _learnColorPsychology,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: _warmWhite,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: _darkText.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Featured Stories',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _darkText,
              ),
            ),
            TextButton(
              onPressed: _exploreStories,
              child: const Text(
                'View All',
                style: TextStyle(
                  color: _forestGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _isLoading
            ? _buildLoadingCards()
            : _featuredStories.isEmpty
                ? _buildEmptyFeaturedState()
                : _buildStoryList(_featuredStories),
      ],
    );
  }

  Widget _buildRecentSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Recent Stories',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _darkText,
          ),
        ),
        const SizedBox(height: 16),
        _recentStories.isEmpty
            ? _buildEmptyRecentState()
            : _buildStoryList(_recentStories),
      ],
    );
  }

  Widget _buildStoryList(List<StoryExperience> stories) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          return _buildStoryCard(story);
        },
      ),
    );
  }

  Widget _buildStoryCard(StoryExperience story) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _forestGreen.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background gradient based on story mood
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _getStoryMoodColors(story.mood),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story.mood.name.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildEmptyFeaturedState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _forestGreen.withValues(alpha: 0.05),
            _sageGreen.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _forestGreen.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 48,
              color: _forestGreen.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Featured stories coming soon!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _darkText.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first story to get started',
              style: TextStyle(
                fontSize: 14,
                color: _darkText.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecentState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _brownAccent.withValues(alpha: 0.05),
            _forestGreen.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _brownAccent.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: _brownAccent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No stories yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _darkText.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your recent stories will appear here',
              style: TextStyle(
                fontSize: 14,
                color: _darkText.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCards() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _forestGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: _forestGreen,
                strokeWidth: 2,
              ),
            ),
          );
        },
      ),
    );
  }

  List<Color> _getStoryMoodColors(StoryMood mood) {
    switch (mood) {
      case StoryMood.serene:
        return [const Color(0xFF6B73FF), const Color(0xFF000DFF)];
      case StoryMood.energetic:
        return [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)];
      case StoryMood.sophisticated:
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case StoryMood.cozy:
        return [const Color(0xFFD66D75), const Color(0xFFE29587)];
      case StoryMood.fresh:
        return [const Color(0xFF56ab2f), const Color(0xFFa8e6cf)];
      case StoryMood.dramatic:
        return [const Color(0xFF434343), const Color(0xFF000000)];
      case StoryMood.natural:
        return [const Color(0xFF8B4513), const Color(0xFFA0522D)];
      case StoryMood.playful:
        return [const Color(0xFFff9a9e), const Color(0xFFfecfef)];
      case StoryMood.minimalist:
        return [const Color(0xFFf7f7f7), const Color(0xFFe8e8e8)];
      case StoryMood.luxurious:
        return [const Color(0xFFFFD700), const Color(0xFFB8860B)];
    }
  }

  void _createImmersiveStory() async {
    final user = FirebaseAuth.instance.currentUser;
    
    setState(() => _isLoading = true);
    
    try {
      // Create sample palette for demo
      final samplePalette = [
        const Color(0xFF4A90E2), // Calming blue
        const Color(0xFF50C878), // Emerald green
        Theme.of(context).colorScheme.secondary, // Warm peach
        const Color(0xFF6B73FF), // Soft purple
      ];

      // Create immersive story context
      final storyContext = ColorStoryContext(
        palette: samplePalette,
        roomType: 'living room',
        lifestyle: 'creative professional',
        mood: 'serene',
        timeOfDay: 'evening person',
        personalStyle: 'minimalist',
        colorMemories: ['ocean sunset', 'forest morning'],
        currentSeason: 'autumn',
        location: 'urban',
      );

      // Create personal touch
      final personalTouch = PersonalTouch(
        userName: user?.displayName ?? 'Beautiful Soul',
        preferences: ['loves natural light', 'works from home'],
        currentSeason: 'autumn',
        location: 'urban',
        lastInteraction: DateTime.now(),
      );

      // Generate immersive story experience
      final narrativeEngine = ImmersiveNarrativeEngine();
      final experience = await narrativeEngine.generateImmersiveStory(
        context: storyContext,
        personalTouch: personalTouch,
        category: StoryCategory.emotionalJourney,
        userId: user?.uid ?? 'demo_user_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
                ImmersiveStoryPlayerScreen(
                  storyExperience: experience,
                  context: storyContext,
                ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating immersive story: $e'),
            backgroundColor: _forestGreen,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _viewMyStories() {
    final user = FirebaseAuth.instance.currentUser;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoryGalleryScreen(
          userId: user?.uid ?? 'demo_user',
        ),
      ),
    );
  }

  void _exploreStories() {
    // Navigate to featured/public stories
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Featured stories coming soon!')),
    );
  }

  void _learnColorPsychology() {
    // Navigate to educational content
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Color psychology lessons coming soon!')),
    );
  }
}
