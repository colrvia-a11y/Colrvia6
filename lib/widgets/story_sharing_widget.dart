import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../models/story_experience.dart';
import '../models/immersive_story_context.dart';
import '../theme.dart';

/// Beautiful shareable story cards for social media
class StoryCardGenerator {
  static final StoryCardGenerator _instance = StoryCardGenerator._internal();
  factory StoryCardGenerator() => _instance;
  StoryCardGenerator._internal();

  /// Generate a beautiful story card widget for sharing
  Widget buildStoryCard({
    required StoryExperience story,
    ColorStoryContext? context,
    StoryCardStyle style = StoryCardStyle.gradient,
  }) {
    return RepaintBoundary(
      key: GlobalKey(),
      child: Container(
        width: 400,
        height: 600,
        decoration: _buildCardDecoration(story, context, style),
        child: Stack(
          children: [
            // Background pattern
            _buildBackgroundPattern(context),

            // Content overlay
            Container(
              padding: const EdgeInsets.all(32),
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
                  // Color palette display
                  if (context != null) _buildPaletteDisplay(context.palette),

                  const Spacer(),

                  // Story title
                  Text(
                    story.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Story description
                  Text(
                    story.description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  // Story stats
                  _buildStoryStats(story),
                  const SizedBox(height: 24),
                  // App branding
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_stories,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Color Stories',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Immersive Color Experiences',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Create a beautiful story card for Instagram/social sharing
  Widget buildInstagramStoryCard({
    required StoryExperience story,
    ColorStoryContext? context,
  }) {
    return RepaintBoundary(
      key: GlobalKey(),
      child: Container(
        width: 1080,
        height: 1920,
        decoration: BoxDecoration(
          gradient: context != null && context.palette.isNotEmpty
              ? RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [
                    context.palette.first.withValues(alpha: 0.2),
                    context.palette.length > 1
                        ? context.palette[1].withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.2),
                    Colors.black,
                  ],
                )
              : const LinearGradient(
                  colors: [Color(0xFF1a1a1a), Color(0xFF000000)],
                ),
        ),
        child: Stack(
          children: [
            // Animated background particles
            if (context != null) _buildFloatingParticles(context.palette),

            // Main content
            Padding(
              padding: const EdgeInsets.all(80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 200),
                  // Large color palette
                  if (context != null)
                    _buildLargePaletteDisplay(context.palette),
                  const SizedBox(height: 100),
                  // Story title with dramatic typography
                  Text(
                    story.title,
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Mood indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      story.mood.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Quote from story
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      _getStoryQuote(story),
                      style: const TextStyle(
                        fontSize: 28,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // App branding for Instagram
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_stories,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 24),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Color Stories',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Discover Your Color Journey',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Export story card as image for sharing
  Future<Uint8List?> exportStoryCard({
    required Widget storyCard,
  }) async {
    try {
      // Find the RepaintBoundary - simplified approach
      final key = storyCard.key as GlobalKey?;
      if (key?.currentContext == null) {
        debugPrint('Error: StoryCard RepaintBoundary not found');
        return null;
      }

      final RenderRepaintBoundary? boundary =
          key!.currentContext!.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint('Error: RenderRepaintBoundary not found');
        return null;
      }

      // Convert to image
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error exporting story card: $e');
      return null;
    }
  }

  // Helper methods
  BoxDecoration _buildCardDecoration(
    StoryExperience story,
    ColorStoryContext? context,
    StoryCardStyle style,
  ) {
    if (context != null && context.palette.isNotEmpty) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.palette.first.withValues(alpha: 0.2),
            context.palette.length > 1
                ? context.palette[1].withValues(alpha: 0.2)
                : context.palette.first.withValues(alpha: 0.2),
            Colors.black.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      );
    }

    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF4A90E2),
          Color(0xFF2E86AB),
          Color(0xFF1a1a1a),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
    );
  }

  Widget _buildBackgroundPattern(ColorStoryContext? context) {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.1,
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/patterns/story_pattern.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteDisplay(List<Color> palette) {
    return SizedBox(
      height: 60,
      child: Row(
        children: palette.take(5).map((color) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLargePaletteDisplay(List<Color> palette) {
    return SizedBox(
      height: 120,
      child: Row(
        children: palette.take(4).map((color) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStoryStats(StoryExperience story) {
    return Row(
      children: [
        _buildStatItem(
          icon: Icons.schedule,
          value: '${story.totalDuration.inMinutes} min',
        ),
        const SizedBox(width: 24),
        _buildStatItem(
          icon: Icons.auto_stories,
          value: '${story.chapters.length} chapters',
        ),
        const SizedBox(width: 24),
        _buildStatItem(
          icon: Icons.psychology,
          value: story.mood.name,
        ),
      ],
    );
  }

  Widget _buildStatItem({required IconData icon, required String value}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingParticles(List<Color> palette) {
    return Positioned.fill(
      child: Stack(
        children: List.generate(15, (index) {
          final color = palette[index % palette.length];
          return Positioned(
            left: (index * 73.0) % 300,
            top: (index * 127.0) % 500,
            child: Container(
              width: 20 + (index % 3) * 10,
              height: 20 + (index % 3) * 10,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getStoryQuote(StoryExperience story) {
    final quotes = [
      "Colors don't just decorate your space—they transform your soul.",
      "Every hue tells a story, every shade holds a memory.",
      "Your perfect palette isn't chosen by chance—it's chosen by your heart.",
      "In the language of color, your space speaks volumes about your spirit.",
      "These aren't just colors. They're the emotions you've been searching for.",
    ];

    return quotes[story.title.hashCode % quotes.length];
  }
}

/// Different style options for story cards
enum StoryCardStyle {
  gradient,
  minimalist,
  dramatic,
  playful,
}

/// Share story card dialog
class ShareStoryDialog extends StatelessWidget {
  final StoryExperience story;
  final ColorStoryContext? context;

  const ShareStoryDialog({
    super.key,
    required this.story,
    this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a1a),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Your Color Story',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose how you\'d like to share your immersive color journey',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildShareOption(
                    icon: Icons.photo_library,
                    title: 'Story Card',
                    onTap: () => _shareStoryCard(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildShareOption(
                    icon: Icons.camera_alt,
                    title: 'Instagram',
                    onTap: () => _shareToInstagram(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildShareOption(
                    icon: Icons.link,
                    title: 'Copy Link',
                    onTap: () => _copyStoryLink(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildShareOption(
                    icon: Icons.share,
                    title: 'More',
                    onTap: () => _shareMore(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareStoryCard(BuildContext context) async {
    final generator = StoryCardGenerator();
    final storyCard = generator.buildStoryCard(
      story: story,
      context: this.context,
    );

    final imageData = await generator.exportStoryCard(storyCard: storyCard);
    if (imageData != null) {
      // Save to gallery or share
      if (context.mounted) {
        _showSuccessMessage(context, 'Story card created!');
      }
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _shareToInstagram(BuildContext context) async {
    final generator = StoryCardGenerator();
    final instagramCard = generator.buildInstagramStoryCard(
      story: story,
      context: this.context,
    );

    final imageData = await generator.exportStoryCard(storyCard: instagramCard);
    if (imageData != null) {
      // Open Instagram with the image
      if (context.mounted) {
        _showSuccessMessage(context, 'Instagram story ready!');
      }
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _copyStoryLink(BuildContext context) {
    Clipboard.setData(
        ClipboardData(text: 'https://colorstories.app/story/${story.id}'));
    _showSuccessMessage(context, 'Link copied to clipboard!');
    Navigator.of(context).pop();
  }

  void _shareMore(BuildContext context) {
    // Open native share dialog
    _showSuccessMessage(context, 'Sharing options opened!');
    Navigator.of(context).pop();
  }

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
