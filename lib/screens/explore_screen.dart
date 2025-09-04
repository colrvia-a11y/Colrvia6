import 'dart:async';
import 'package:flutter/material.dart' as m;
import 'package:flutter/material.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Minimal state preserved for future expansion
  Timer? _searchDebounce;
  final Duration _searchDelay = const Duration(milliseconds: 500);
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    setState(() => _searchQuery = query);
    _searchDebounce = Timer(_searchDelay, () {
      // hook for analytics/search later
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Color Stories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _isLoading = !_isLoading),
            tooltip: 'Toggle loading',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search stories, styles, or rooms…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear',
                      )
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildPlaceholderGrid(theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Create'),
      ),
    );
  }

  Widget _buildPlaceholderGrid(ThemeData theme) {
    final bottomPadding = 24 + kBottomNavigationBarHeight + MediaQuery.of(context).padding.bottom;
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return _CardSkeleton(index: index);
      },
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Material(
      color: color.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    colors: [
                      Colors
                          .primaries[index % Colors.primaries.length].shade400,
                      Colors.primaries[(index + 3) % Colors.primaries.length]
                          .shade200,
                    ],
                  ),
                ),
              ),
            ),
            const Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Beautiful Color Story',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    m.SizedBox(height: 6),
                    Text('AI Generated',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
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
/*
  void _toggleTheme(String theme) {
    final wasSelected = _selectedThemes.contains(theme);
    setState(() {
      if (wasSelected) {
        _selectedThemes.remove(theme);
      } else {
        _selectedThemes.add(theme);
      }
    });
    
    // Enhanced analytics tracking
    AnalyticsService.instance.trackExploreFilterChange(
      selectedThemes: _selectedThemes.toList(),
      selectedFamilies: _selectedFamilies.toList(),
      selectedRooms: _selectedRooms.toList(),
      changeType: wasSelected ? 'theme_removed' : 'theme_added',
      totalResultCount: _filteredStories.length,
    );
    
    _onFilterChanged();
  }

  void _toggleFamily(String family) {
    final wasSelected = _selectedFamilies.contains(family);
    setState(() {
      if (wasSelected) {
        _selectedFamilies.remove(family);
      } else {
        _selectedFamilies.add(family);
      }
    });
    
    // Enhanced analytics tracking
    AnalyticsService.instance.trackExploreFilterChange(
      selectedThemes: _selectedThemes.toList(),
      selectedFamilies: _selectedFamilies.toList(),
      selectedRooms: _selectedRooms.toList(),
      changeType: wasSelected ? 'family_removed' : 'family_added',
      totalResultCount: _filteredStories.length,
    );
    
    _onFilterChanged();
  }

  void _toggleRoom(String room) {
    final wasSelected = _selectedRooms.contains(room);
    setState(() {
      if (wasSelected) {
        _selectedRooms.remove(room);
      } else {
        _selectedRooms.add(room);
      }
    });
    
    // Enhanced analytics tracking
    AnalyticsService.instance.trackExploreFilterChange(
      selectedThemes: _selectedThemes.toList(),
      selectedFamilies: _selectedFamilies.toList(),
      selectedRooms: _selectedRooms.toList(),
      changeType: wasSelected ? 'room_removed' : 'room_added',
      totalResultCount: _filteredStories.length,
    );
    
    _onFilterChanged();
  }

  List<ColorStory> _getSampleStories() {
    // Sample data for development/offline mode - using fromSnap constructor
    final sampleData1 = {
      'userId': 'sample-user',
      'title': 'Coastal Serenity',
      'slug': 'coastal-serenity',
      'heroImageUrl': 'https://pixabay.com/get/g1d5c9aa83a66d093c7e4b4fc7b97b2b2a83ae7a311c8f2f0d621269c20bd3109f26e62dbe18eb3717b515c4738252cdef0a5fb70596b60152ed0ed0b61c5ddef_1280.jpg',
      'themes': ['coastal', 'contemporary'],
      'families': ['blues', 'neutrals'],
      'rooms': ['living', 'bedroom'],
      'tags': ['ocean', 'calming', 'fresh'],
      'description': 'Inspired by ocean waves and sandy shores',
      'isFeatured': true,
      'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
      'updatedAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
      'facets': ['theme:coastal', 'theme:contemporary', 'family:blues', 'family:neutrals', 'room:living', 'room:bedroom'],
      'status': 'complete',
      'access': 'public',
      'narration': 'A serene coastal palette that brings the tranquil beauty of ocean waters into your home.',
      'palette': [
        {
          'role': 'main',
          'hex': '#4A90A4',
          'name': 'Ocean Blue',
          'brandName': 'Sherwin-Williams',
          'code': 'SW 6501',
          'psychology': 'Promotes tranquility and calm, evoking the serenity of ocean depths.',
          'usageTips': 'Perfect for bedrooms and bathrooms where relaxation is key.',
        },
        {
          'role': 'accent',
          'hex': '#E8F4F8',
          'name': 'Sea Foam',
          'brandName': 'Benjamin Moore',
          'code': 'OC-58',
          'psychology': 'Light and airy, creates a sense of freshness and renewal.',
          'usageTips': 'Ideal for trim work and ceiling accents to brighten spaces.',
        },
        {
          'role': 'trim',
          'hex': '#F5F5DC',
          'name': 'Sandy Beige',
          'brandName': 'Behr',
          'code': 'N240-1',
          'psychology': 'Warm and grounding, provides stability and comfort.',
          'usageTips': 'Use as a neutral base to balance cooler tones.',
        },
      ],
    };
    
    final sampleData2 = {
      'userId': 'sample-user',
      'title': 'Modern Farmhouse',
      'slug': 'modern-farmhouse',
      'heroImageUrl': 'https://pixabay.com/get/ga04013479135d1420a173525047d5aa53d70a7cef34a22c34c59d3edfee6daff2a8feee41d7e42aac0dd6462898e291ef492fa25b9984dd761c6f49b9cf20a68_1280.jpg',
      'themes': ['modern-farmhouse', 'rustic'],
      'families': ['warm-neutrals', 'whites'],
      'rooms': ['kitchen', 'dining'],
      'tags': ['cozy', 'natural', 'warm'],
      'description': 'Warm and inviting farmhouse aesthetic',
      'isFeatured': false,
      'createdAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2))),
      'updatedAt': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2))),
      'facets': ['theme:modern-farmhouse', 'theme:rustic', 'family:warm-neutrals', 'family:whites', 'room:kitchen', 'room:dining'],
      'status': 'complete',
      'access': 'public',
      'narration': 'A cozy farmhouse palette that combines rustic charm with modern sophistication.',
      'palette': [
        {
          'role': 'main',
          'hex': '#F7F3E9',
          'name': 'Creamy White',
          'brandName': 'Benjamin Moore',
          'code': 'OC-14',
          'psychology': 'Warm and inviting, creates a cozy and welcoming atmosphere.',
          'usageTips': 'Excellent for main walls in kitchens and dining areas.',
        },
        {
          'role': 'accent',
          'hex': '#8B7355',
          'name': 'Weathered Wood',
          'brandName': 'Sherwin-Williams',
          'code': 'SW 2841',
          'psychology': 'Natural and rustic, brings warmth and earthiness to spaces.',
          'usageTips': 'Perfect for accent walls and built-in cabinetry.',
        },
        {
          'role': 'trim',
          'hex': '#2F2F2F',
          'name': 'Charcoal',
          'brandName': 'Behr',
          'code': 'S350-7',
          'psychology': 'Bold and sophisticated, adds depth and contrast.',
          'usageTips': 'Use sparingly on trim and window frames for definition.',
        },
      ],
    };
    
    return [
      ColorStory.fromSnap('sample-1', sampleData1),
      ColorStory.fromSnap('sample-2', sampleData2),
    ];
  }

  void _navigateToStory(String storyId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ColorPlanDetailScreen(storyId: storyId),
      ),
    );
    
    // Track analytics
    AnalyticsService.instance.logEvent('spotlight_story_tapped', {
      'story_id': storyId,
      'source': 'spotlight_rail',
    });
  }
  
  void _showAllSpotlights() {
    // For now, just reload the main stories with a spotlight filter
    // In a real implementation, you would modify the query to filter by spotlight=true
    
    // Track analytics
    AnalyticsService.instance.logEvent('spotlight_see_all_tapped', {
      'spotlight_count': _spotlightStories.length,
    });
    
    // Show snackbar to indicate spotlight filter
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing ${_spotlightStories.length} spotlight stories'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View All',
          onPressed: () {
            // Reset to normal explore view
            _loadColorStories();
          },
        ),
      ),
    );
  }
  
  Future<void> _checkUserPalettes() async {
    try {
      final userId = FirebaseService.currentUser?.uid;
      if (userId != null) {
        final palettes = await FirebaseService.getUserPalettes(userId);
        setState(() {
          _hasUserPalettes = palettes.isNotEmpty;
        });
      }
    } catch (e) {
      // Silently fail - just keep FAB showing StoryStudio as fallback
      debugPrint('Error checking user palettes: $e');
    }
  }

  Future<void> _createNewStory() async {
    // Ensure user is signed in before creating project
    await AuthGuard.ensureSignedIn(context);
    
    // Create project first, then navigate to wizard
    try {
      final project = await ProjectService.create(
        title: 'New Color Story',
      );
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ColorPlanScreen(projectId: project.id),
          ),
        );
        
        AnalyticsService.instance.logEvent('explore_new_story_main_cta', {
          'has_palettes': _hasUserPalettes,
          'destination': 'color_story_wizard',
          'project_id': project.id,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to create color stories')),
        );
      }
    }
  }

  void _showBrowseStoriesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Browse Color Stories',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search stories or tags…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              // Filter Chips
              SizedBox(
                height: 120,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilterSection('Style', _themeOptions, _selectedThemes, _toggleTheme),
                      const SizedBox(height: 8),
                      _buildFilterSection('Family', _familyOptions, _selectedFamilies, _toggleFamily),
                      const SizedBox(height: 8),
                      _buildFilterSection('Room', _roomOptions, _selectedRooms, _toggleRoom),
                    ],
                  ),
                ),
              ),
              
              const Divider(height: 1),
              
              // Results Grid
              Expanded(
                child: _buildResultsGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(BuildContext context) {
    return Stack(
      children: [
        // Gradient base
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A0A0B),
                Color(0xFF1A1A1D),
                Color(0xFF0A0A0B),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
        
        // Animated particles
        ...List.generate(15, (index) {
          return TweenAnimationBuilder(
            duration: Duration(seconds: 10 + (index % 5)),
            tween: Tween<double>(begin: 0, end: 2 * math.pi),
            builder: (context, value, child) {
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;
              
              return Positioned(
                left: screenWidth * (0.1 + (index * 0.08) % 0.8) + math.sin(value) * 30,
                top: screenHeight * (0.1 + (index * 0.1) % 0.8) + math.cos(value) * 20,
                child: Container(
                  width: 4 + (index % 3) * 2,
                  height: 4 + (index % 3) * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: [
                      const Color(0xFF6366F1),
                      const Color(0xFF8B5CF6),
                      const Color(0xFFEC4899),
                      const Color(0xFF06B6D4),
                    ][index % 4].withValues(alpha: 0.3 + math.sin(value) * 0.2),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildPremiumFeaturesSection() {
    final features = [
      {
        'icon': Icons.psychology_alt_outlined,
        'title': 'Neural Color Intelligence',
        'subtitle': 'Advanced AI Psychology',
        'description': 'Harness the power of color psychology with our proprietary neural networks that understand human emotion and perception.',
        'gradient': [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      },
      {
        'icon': Icons.view_in_ar_outlined,
        'title': 'Immersive Visualization',
        'subtitle': 'Photorealistic Preview',
        'description': 'Experience your colors in stunning 3D environments with our advanced rendering engine and lighting simulation.',
        'gradient': [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
      },
      {
        'icon': Icons.auto_fix_high_outlined,
        'title': 'Precision Harmony',
        'subtitle': 'Mathematical Perfection',
        'description': 'Our algorithms analyze millions of color relationships to create mathematically perfect, emotionally resonant palettes.',
        'gradient': [const Color(0xFFEC4899), const Color(0xFF06B6D4)],
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 32),
      child: Column(
        children: [
          // Section Header
          Text(
            'Experience Excellence',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600 ? 36 : 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Where cutting-edge technology meets\nintuitive design mastery',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.6,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 80),
          
          // Feature Cards
          ...features.asMap().entries.map((entry) {
            final index = entry.key;
            final feature = entry.value;
            final isEven = index % 2 == 0;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 60),
              child: Row(
                children: [
                  if (isEven) ...[
                    Expanded(child: _buildFeatureCard(feature)),
                    const SizedBox(width: 40),
                    Expanded(child: _buildFeatureVisual(feature, index)),
                  ] else ...[
                    Expanded(child: _buildFeatureVisual(feature, index)),
                    const SizedBox(width: 40),
                    Expanded(child: _buildFeatureCard(feature)),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: feature['gradient'] as List<Color>,
              ),
            ),
            child: Icon(
              feature['icon'] as IconData,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            feature['subtitle'] as String,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: (feature['gradient'] as List<Color>)[0],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feature['title'] as String,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            feature['description'] as String,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureVisual(Map<String, dynamic> feature, int index) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: feature['gradient'] as List<Color>,
        ),
      ),
      child: Stack(
        children: [
          // Animated pattern overlay
          Positioned.fill(
            child: TweenAnimationBuilder(
              duration: const Duration(seconds: 8),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, value, child) {
                return CustomPaint(
                  painter: _FeaturePatternPainter(value, index),
                );
              },
            ),
          ),
          
          // Central icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                feature['icon'] as IconData,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveProcessSection() {
    final steps = [
      {
        'number': '01',
        'title': 'Inspiration Capture',
        'description': 'Upload an image, select from your palette, or let our AI suggest colors based on your style preferences.',
        'icon': Icons.camera_alt_outlined,
        'color': const Color(0xFF6366F1),
      },
      {
        'number': '02',
        'title': 'AI Enhancement',
        'description': 'Our neural networks analyze color harmony, psychology, and spatial relationships to perfect your palette.',
        'icon': Icons.auto_fix_high_outlined,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'number': '03',
        'title': 'Immersive Preview',
        'description': 'Experience your colors in photorealistic 3D spaces with dynamic lighting and material simulation.',
        'icon': Icons.view_in_ar_outlined,
        'color': const Color(0xFFEC4899),
      },
      {
        'number': '04',
        'title': 'Story Creation',
        'description': 'Generate your personalized color narrative with professional insights and emotional connections.',
        'icon': Icons.auto_stories_outlined,
        'color': const Color(0xFF06B6D4),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 32),
      child: Column(
        children: [
          // Section Header
          Text(
            'Your Creative Journey',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600 ? 36 : 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Four steps to color mastery',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 80),
          
          // Interactive Steps
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;
            
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step Number with Animation
                    Column(
                      children: [
                        TweenAnimationBuilder(
                          duration: Duration(milliseconds: 1000 + (index * 200)),
                          tween: Tween<double>(begin: 0, end: 1),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (0.2 * value),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      step['color'] as Color,
                                      (step['color'] as Color).withValues(alpha: 0.6),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (step['color'] as Color).withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      step['icon'] as IconData,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      step['number'] as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        
                        // Connector Line
                        if (!isLast)
                          TweenAnimationBuilder(
                            duration: Duration(milliseconds: 1500 + (index * 200)),
                            tween: Tween<double>(begin: 0, end: 1),
                            builder: (context, value, child) {
                              return Container(
                                width: 2,
                                height: 80,
                                margin: const EdgeInsets.symmetric(vertical: 20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      (step['color'] as Color).withValues(alpha: value),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    
                    const SizedBox(width: 32),
                    
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['title'] as String,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              step['description'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.7),
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isLast) const m.SizedBox(height: 40),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSocialProofSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 32),
      child: Column(
        children: [
          Text(
            'Trusted by Creators',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600 ? 36 : 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 60),
          
          // Recent Stories Carousel
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: math.min(_spotlightStories.length, 6),
              itemBuilder: (context, index) {
                final story = _spotlightStories[index];
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 20),
                  child: _buildGlassyStoryCard(story, index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassyStoryCard(ColorStory story, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _navigateToStory(story.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Image with Gradient
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(
                      colors: [
                        ColorStoryCard._extractFirstColor(story).isNotEmpty 
                          ? Color(int.parse(ColorStoryCard._extractFirstColor(story).substring(1), radix: 16) + 0xFF000000)
                          : const Color(0xFF6366F1),
                        ColorStoryCard._extractSecondColor(story).isNotEmpty
                          ? Color(int.parse(ColorStoryCard._extractSecondColor(story).substring(1), radix: 16) + 0xFF000000)
                          : const Color(0xFF8B5CF6),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Content
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.narration.isNotEmpty 
                          ? story.narration.split(' ').take(6).join(' ')
                          : 'Beautiful Story',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'AI Generated',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withOpacity(0.6),
                            size: 12,
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
      ),
    );
  }

  Widget _buildFinalCTASection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ready to Begin?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600 ? 32 : 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your color story awaits',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 40),
          
          // Final CTA Button
          Container(
            width: 280,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                  Color(0xFFEC4899),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.6),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(32),
                onTap: _createNewStory,
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Start Creating',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: Stack(
        children: [
          // Animated Background with Color Particles
          Positioned.fill(
            child: _buildAnimatedBackground(context),
          ),
          
          // Main Content
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Hero Section - Full Screen Experience
                SizedBox(
                  height: screenHeight * 0.85,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      // Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.5,
                            colors: [
                              const Color(0xFF6366F1).withOpacity(0.15),
                              const Color(0xFF8B5CF6).withOpacity(0.08),
                              const Color(0xFF0A0A0B).withOpacity(0.95),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                      
                      // Main Hero Content
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Animated Logo/Icon
                              TweenAnimationBuilder(
                                duration: const Duration(seconds: 2),
                                tween: Tween<double>(begin: 0, end: 1),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: 0.8 + (0.2 * value),
                                    child: Opacity(
                                      opacity: value,
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF6366F1),
                                              Color(0xFF8B5CF6),
                                              Color(0xFFEC4899),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                              blurRadius: 40,
                                              spreadRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome,
                                          size: 56,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              ),
                              
                              const SizedBox(height: 48),
                              
                              // Main Headline - Cinematic Typography
                              TweenAnimationBuilder(
                                duration: const Duration(milliseconds: 1500),
                                tween: Tween<double>(begin: 0, end: 1),
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 30 * (1 - value)),
                                    child: Opacity(
                                      opacity: value,
                                      child: ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          colors: [
                                            Color(0xFFFFFFFF),
                                            Color(0xFFE5E7EB),
                                            Color(0xFF9CA3AF),
                                          ],
                                          stops: [0.0, 0.5, 1.0],
                                        ).createShader(bounds),
                                        child: Text(
                                          'Craft Your\nColor Story',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: screenWidth > 600 ? 56 : 42,
                                            fontWeight: FontWeight.w900,
                                            height: 1.1,
                                            letterSpacing: -1.5,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Subtitle with Typewriter Effect
                              TweenAnimationBuilder(
                                duration: const Duration(milliseconds: 2000),
                                tween: Tween<double>(begin: 0, end: 1),
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: Opacity(
                                      opacity: value,
                                      child: Text(
                                        'Where colors become poetry.\nWhere design meets emotion.\nWhere your vision comes alive.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: screenWidth > 600 ? 20 : 16,
                                          fontWeight: FontWeight.w400,
                                          height: 1.6,
                                          letterSpacing: 0.5,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 64),
                              
                              // Epic CTA Button
                              TweenAnimationBuilder(
                                duration: const Duration(milliseconds: 2500),
                                tween: Tween<double>(begin: 0, end: 1),
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: 0.9 + (0.1 * value),
                                    child: Opacity(
                                      opacity: value,
                                      child: Container(
                                        width: screenWidth > 600 ? 280 : 240,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(32),
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF6366F1),
                                              Color(0xFF8B5CF6),
                                              Color(0xFFEC4899),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF6366F1).withOpacity(0.6),
                                              blurRadius: 30,
                                              spreadRadius: 5,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(32),
                                            onTap: _createNewStory,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 32),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.auto_awesome,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Begin Creation',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: screenWidth > 600 ? 20 : 18,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Floating Scroll Indicator
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: TweenAnimationBuilder(
                          duration: const Duration(seconds: 3),
                          tween: Tween<double>(begin: 0, end: 1),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value * 0.6,
                              child: Column(
                                children: [
                                  Text(
                                    'Discover More',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TweenAnimationBuilder(
                                    duration: const Duration(seconds: 2),
                                    tween: Tween<double>(begin: 0, end: 10),
                                    builder: (context, value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, math.sin(value) * 3),
                                        child: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white.withValues(alpha: 0.6),
                                          size: 32,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Features Section - Premium Design
                Container(
                  color: const Color(0xFF0F0F10),
                  child: _buildPremiumFeaturesSection(),
                ),
                
                // Process Section - Interactive
                Container(
                  color: const Color(0xFF0A0A0B),
                  child: _buildInteractiveProcessSection(),
                ),
                
                // Social Proof / Testimonials (if stories available)
                if (_spotlightStories.isNotEmpty)
                  Container(
                    color: const Color(0xFF0F0F10),
                    child: _buildSocialProofSection(),
                  ),
                
                // Final CTA Section
                Container(
                  height: 300,
                  color: const Color(0xFF0A0A0B),
                  child: _buildFinalCTASection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options, Set<String> selected, Function(String) onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: options.map((option) => FilterChip(
            label: Text(
              option.replaceAll('-', ' '),
              style: const TextStyle(fontSize: 12),
            ),
            selected: selected.contains(option),
            onSelected: (_) => onToggle(option),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildSpotlightCard(ColorStory story, int index) {
    return Container(
      width: 200,
      margin: EdgeInsets.only(right: index < _spotlightStories.length - 1 ? 12 : 0),
      child: InkWell(
        onTap: () => _navigateToStory(story.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero image
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: story.heroImageUrl?.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: story.heroImageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) => _buildSpotlightGradientFallback(story),
                          errorWidget: (_, __, ___) => _buildSpotlightGradientFallback(story),
                        )
                      : _buildSpotlightGradientFallback(story),
                ),
              ),
              
              // Story info
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        story.narration.isNotEmpty 
                          ? story.narration.split(' ').take(4).join(' ')
                          : 'Beautiful Color Story',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Designer attribution and likes
                      Row(
                        children: [
                          // Designer attribution
                          Expanded(
                            child: Text(
                              'AI Generated',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // Likes placeholder - would need to be fetched from firestore
                          if (story.access == 'public') ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.favorite,
                              size: 14,
                              color: Colors.red.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '0', // Placeholder - would need actual like count
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
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
  
  Widget _buildSpotlightGradientFallback(ColorStory story) {
    // Extract colors from usage guide for gradient
    String firstColor = '#6366F1';
    String secondColor = '#8B5CF6';
    
    if (story.usageGuide.isNotEmpty) {
      final validColors = story.usageGuide
          .where((item) => item.hex.isNotEmpty)
          .map((item) => item.hex)
          .toList();
      
      if (validColors.isNotEmpty) {
        firstColor = validColors.first;
        if (validColors.length > 1) {
          secondColor = validColors[1];
        }
      }
    }
    
    return GradientHeroUtils.buildGradientFallback(
      colorA: firstColor,
      colorB: secondColor,
      child: Center(
        child: Icon(
          Icons.palette,
          color: Colors.white.withValues(alpha: 0.8),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildResultsGrid() {
    if (_isLoading && _filteredStories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading color stories...'),
          ],
        ),
      );
    }
    
    if (_hasError && _filteredStories.isEmpty) {
      return _buildErrorState();
    }

    if (_filteredStories.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getGridCrossAxisCount(context),
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredStories.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredStories.length) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        return ColorStoryCard(story: _filteredStories[index], wifiOnlyPref: _wifiOnlyAssets);
      },
    );
  }

  Widget _buildEmptyState() {
    final suggestion = _buildDynamicSuggestion();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const m.SizedBox(height: 12),
            Text(
              'No color stories found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const m.SizedBox(height: 12),
            Text(
              suggestion['message'] ?? 'Try adjusting your filters or search terms',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),
            const m.SizedBox(height: 24),
            if (_selectedThemes.isNotEmpty || _selectedFamilies.isNotEmpty || _selectedRooms.isNotEmpty || _searchQuery.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    AnalyticsService.instance.trackColorStoriesEngagement(
                      action: 'clear_filters_from_empty_state',
                      additionalData: {
                        'had_themes': _selectedThemes.isNotEmpty,
                        'had_families': _selectedFamilies.isNotEmpty,
                        'had_rooms': _selectedRooms.isNotEmpty,
                        'had_search': _searchQuery.isNotEmpty,
                      },
                    );
                    setState(() {
                      _selectedThemes.clear();
                      _selectedFamilies.clear();
                      _selectedRooms.clear();
                      _searchQuery = '';
                      _searchController.clear();
                    });
                    _onFilterChanged();
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear filters'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// Build dynamic suggestion message based on current filter state
  Map<String, String> _buildDynamicSuggestion() {
    final hasThemes = _selectedThemes.isNotEmpty;
    final hasFamilies = _selectedFamilies.isNotEmpty;
    final hasRooms = _selectedRooms.isNotEmpty;
    final hasSearch = _searchQuery.isNotEmpty;
    
    // If all three filter categories are selected, suggest removing the most restrictive one
    if (hasThemes && hasFamilies && hasRooms) {
      return {
        'message': 'This combination might be too specific. Try removing one of your filters to find more stories.',
        'action': 'remove_filter_combination',
      };
    }
    
    // If search query + multiple filters
    if (hasSearch && (hasThemes || hasFamilies || hasRooms)) {
      return {
        'message': 'Your search combined with filters might be too narrow. Try clearing your search or removing some filters.',
        'action': 'simplify_search_and_filters',
      };
    }
    
    // If only search query
    if (hasSearch && !hasThemes && !hasFamilies && !hasRooms) {
      return {
        'message': 'No stories match your search. Try different keywords or browse by style instead.',
        'action': 'modify_search_query',
      };
    }
    
    // If only rooms are selected (most restrictive)
    if (hasRooms && !hasThemes && !hasFamilies) {
      return {
        'message': 'Try adding a color family like "neutrals" or "blues" to find stories for this room.',
        'action': 'add_family_filter',
      };
    }
    
    // If themes + families but no rooms
    if (hasThemes && hasFamilies && !hasRooms) {
      return {
        'message': 'This style and color combination might be rare. Try expanding to more color families.',
        'action': 'expand_families',
      };
    }
    
    // If only themes selected
    if (hasThemes && !hasFamilies && !hasRooms) {
      return {
        'message': 'Try adding a color family like "neutrals" or "warm-neutrals" to discover stories in this style.',
        'action': 'add_family_to_theme',
      };
    }
    
    // If only families selected
    if (hasFamilies && !hasThemes && !hasRooms) {
      return {
        'message': 'Try adding a style like "modern-farmhouse" or "contemporary" to find stories with these colors.',
        'action': 'add_theme_to_family',
      };
    }
    
    // Default case (no filters)
    return {
      'message': 'No color stories available right now. Check your connection or try again later.',
      'action': 'connection_issue',
    };
  }
  
  // Error handling is now done inline in the UI instead of global SnackBars
  
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage.isNotEmpty ? _errorMessage : 'Unable to load color stories. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = '';
                    });
                    _loadColorStories();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _errorMessage = '';
                      _stories = _getSampleStories();
                      _applyTextFilter();
                    });
                  },
                  icon: const Icon(Icons.preview),
                  label: const Text('View Samples'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  int _getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4; // Desktop
    if (width > 600) return 3;  // Tablet
    return 2;                   // Mobile
  }
}

class ColorStoryCard extends StatelessWidget {
  final ColorStory story;
  final bool wifiOnlyPref;

  const ColorStoryCard({super.key, required this.story, this.wifiOnlyPref = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Track story open analytics
          AnalyticsService.instance.trackColorStoryOpen(
            storyId: story.id,
            slug: story.slug,
            title: story.title,
            source: 'explore',
          );
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ColorPlanDetailScreen(storyId: story.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image with Palette Preview
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (story.heroImageUrl != null || story.fallbackHero.isNotEmpty)
                    ClipRRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Always show gradient fallback first for instant render
                          if (story.fallbackHero.isNotEmpty)
                            GradientHeroUtils.buildGradientFallback(
                              colorA: ColorStoryCard._extractFirstColor(story),
                              colorB: ColorStoryCard._extractSecondColor(story),
                              child: Center(
                                child: Icon(
                                  Icons.palette,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 24,
                                ),
                              ),
                            ),
                          
                          // Network-aware hero image loading
                          if (story.heroImageUrl != null)
                            NetworkAwareImage(
                              imageUrl: story.heroImageUrl!,
                              wifiOnlyPref: wifiOnlyPref,
                              fit: BoxFit.cover,
                              isHeavyAsset: true,
                              placeholder: const SizedBox.shrink(),
                              errorWidget: const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    )
                  else
                    _buildPalettePreview(),
                  
                  // Featured badge and menu
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (story.isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Featured',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (story.isFeatured) const SizedBox(width: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 16,
                            ),
                            padding: EdgeInsets.zero,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'use_start',
                                child: const Text('Use as Starting Point'),
                              ),
                              PopupMenuItem(
                                value: 'view_details',
                                child: const Text('View Details'),
                              ),
                            ],
                            onSelected: (value) async {
                              switch (value) {
                                case 'use_start':
                                  await _handleUseAsStartingPoint(context, story);
                                  break;
                                case 'view_details':
                                  _navigateToStoryDetail(context, story);
                                  break;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // v3: Processing/queued spinner badge (top-left)
                  if (story.status == 'processing' || story.status == 'queued')
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: story.status == 'processing' 
                              ? Colors.blue.shade600 
                              : Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              story.status == 'processing' ? 'Processing' : 'Queued',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // v3: Like count badge (bottom-left)
                  if (story.likeCount > 0)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              story.likeCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel: story.title,
                    ),
                    const SizedBox(height: 4),
                    if (story.tags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: story.tags.take(3).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        )).toList(),
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

  static String _extractFirstColor(ColorStory story) {
    if (story.usageGuide.isNotEmpty && story.usageGuide.first.hex.isNotEmpty) {
      return story.usageGuide.first.hex;
    }
    if (story.palette.isNotEmpty && story.palette.first.hex.isNotEmpty) {
      return story.palette.first.hex;
    }
    return '#6366F1'; // Default indigo
  }

  static String _extractSecondColor(ColorStory story) {
    if (story.usageGuide.length > 1 && story.usageGuide[1].hex.isNotEmpty) {
      return story.usageGuide[1].hex;
    }
    if (story.palette.length > 1 && story.palette[1].hex.isNotEmpty) {
      return story.palette[1].hex;
    }
    if (story.usageGuide.isNotEmpty && story.usageGuide.first.hex.isNotEmpty) {
      return story.usageGuide.first.hex;
    }
    if (story.palette.isNotEmpty && story.palette.first.hex.isNotEmpty) {
      return story.palette.first.hex;
    }
    return '#8B5CF6'; // Default purple
  }

  Widget _buildPalettePreview() {
    if (story.palette.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(
            Icons.palette_outlined,
            size: 32,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Row(
      children: story.palette.take(5).map((color) {
        final colorValue = int.parse(color.hex.substring(1), radix: 16) + 0xFF000000;
        return Expanded(
          child: Container(
            color: Color(colorValue),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _handleUseAsStartingPoint(BuildContext context, ColorStory story) async {
    try {
      // Ensure user is signed in before creating project
      await AuthGuard.ensureSignedIn(context);
      
      // First, we need to get the palette ID from the story
      // Since ColorStory might not directly expose paletteId, we'll create a new palette from the story's colors
      final user = FirebaseService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to create a Color Story')),
        );
        return;
      }
      
      // Convert story palette colors to PaletteColor format
      final paletteColors = story.palette.asMap().entries.map((entry) {
        final color = entry.value;
        return schema.PaletteColor(
          paintId: color.paintId?.isNotEmpty == true ? color.paintId! : 'imported_${color.hex}',
          locked: false,
          position: entry.key,
          brand: color.brandName?.isNotEmpty == true ? color.brandName : 'Unknown',
          name: color.name?.isNotEmpty == true ? color.name! : 'Color ${entry.key + 1}',
          code: color.code?.isNotEmpty == true ? color.code! : color.hex,
          hex: color.hex,
        );
      }).toList();
      
      if (paletteColors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This story has no colors to use')),
        );
        return;
      }
      
      // Create a new palette based on the story
      final seededPaletteId = await FirebaseService.createPalette(
        userId: user.uid,
        name: '${story.title} (Remix)',
        colors: paletteColors,
        tags: [...story.tags, 'remix'],
        notes: 'Based on: ${story.title}',
      );
      
      // Create project
      final project = await ProjectService.create(
        title: '${story.title} (Remix)',
        paletteId: seededPaletteId,
      );
      
      // Track start from explore
      AnalyticsService.instance.logStartFromExplore(story.id, project.id);
      
      // Navigate to Roller with success feedback
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RollerScreen()));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Started new Color Story from "${story.title}"'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // Navigate back to dashboard to see the project
              Navigator.of(context).pushReplacementNamed('/home');
            },
          ),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating Color Story: $e')),
      );
    }
  }

  void _navigateToStoryDetail(BuildContext context, ColorStory story) {
    // Track story open analytics
    AnalyticsService.instance.trackColorStoryOpen(
      storyId: story.id,
      slug: story.slug,
      title: story.title,
      source: 'explore_menu',
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ColorPlanDetailScreen(storyId: story.id),
      ),
    );
  }
}

// Custom Painter for Feature Visuals
class _FeaturePatternPainter extends CustomPainter {
  final double animationValue;
  final int patternType;
  
  _FeaturePatternPainter(this.animationValue, this.patternType);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paintBrush = ui.Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 2
      ..style = ui.PaintingStyle.stroke;
    
    final center = Offset(size.width / 2, size.height / 2);
    
    switch (patternType % 3) {
      case 0:
        // Concentric circles
        for (int i = 1; i <= 4; i++) {
          final radius = (size.width / 8) * i * animationValue;
          final circlePaint = ui.Paint()
            ..color = Colors.white.withOpacity(0.1 - (i * 0.02))
            ..strokeWidth = 2
            ..style = ui.PaintingStyle.stroke;
          canvas.drawCircle(center, radius, circlePaint);
        }
        break;
      case 1:
        // Geometric pattern
        final path = Path();
        final points = 6;
        for (int i = 0; i < points; i++) {
          final angle = (2 * math.pi / points) * i + (animationValue * 2 * math.pi);
          final radius = size.width / 4;
          final x = center.dx + radius * math.cos(angle);
          final y = center.dy + radius * math.sin(angle);
          
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paintBrush);
        break;
      case 2:
        // Spiraling lines
        final path = Path();
        for (double t = 0; t < 4 * math.pi * animationValue; t += 0.1) {
          final radius = t * 2;
          final x = center.dx + radius * math.cos(t);
          final y = center.dy + radius * math.sin(t);
          
          if (t == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, paintBrush);
        break;
    }
  }
  
  @override
  bool shouldRepaint(_FeaturePatternPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}
*/
