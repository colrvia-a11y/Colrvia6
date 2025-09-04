import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/color_story.dart';
import '../models/story_experience.dart';

/// Service for managing immersive color story experiences
class StoryEngine {
  static final StoryEngine _instance = StoryEngine._internal();
  factory StoryEngine() => _instance;
  StoryEngine._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  /// Generate a personalized story experience from a user's color palette
  Future<StoryExperience> generateStoryFromPalette({
    required String userId,
    required ColorStory colorStory,
    required StoryMood mood,
    Map<String, dynamic>? userPreferences,
  }) async {
    try {
      // Analyze the color palette to extract emotional themes
      final colorAnalysis = _analyzeColorPalette(colorStory.palette);

      // Generate story structure based on mood and colors
      final chapters = await _generateChapters(
        colorStory: colorStory,
        mood: mood,
        colorAnalysis: colorAnalysis,
        userPreferences: userPreferences ?? {},
      );

      // Calculate total duration
      final totalDuration = chapters.fold<Duration>(
        Duration.zero,
        (total, chapter) => total + chapter.duration,
      );

      // Create the story experience
      final experience = StoryExperience(
        id: _generateId(),
        userId: userId,
        title: _generateTitle(mood, colorAnalysis),
        description: _generateDescription(mood, colorStory),
        mood: mood,
        chapters: chapters,
        totalDuration: totalDuration,
        userPreferences: userPreferences ?? {},
        lastPlayedAt: DateTime.now(),
        isCustomGenerated: true,
        sourceColorStoryId: colorStory.id,
      );

      // Save to Firestore
      await _firestore
          .collection('story_experiences')
          .doc(experience.id)
          .set(experience.toJson());

      return experience;
    } catch (e) {
      debugPrint('Error generating story from palette: $e');
      rethrow;
    }
  }

  /// Get user's story experiences
  Stream<List<StoryExperience>> getUserStoryExperiences(String userId) {
    return _firestore
        .collection('story_experiences')
        .where('userId', isEqualTo: userId)
        .orderBy('lastPlayedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StoryExperience.fromFirestore(doc))
            .toList());
  }

  /// Update story progress
  Future<void> updateStoryProgress({
    required String experienceId,
    required String chapterId,
    double? progress,
    Map<String, dynamic>? analyticsData,
  }) async {
    final docRef = _firestore.collection('story_experiences').doc(experienceId);

    final updateData = <String, dynamic>{
      'lastPlayedAt': Timestamp.now(),
    };

    if (progress != null) {
      updateData['completionProgress'] = progress;
    }

    // Mark chapter as completed if progress indicates completion
    if (progress != null && progress >= 1.0) {
      updateData['completedChapterIds'] = FieldValue.arrayUnion([chapterId]);
    }

    if (analyticsData != null) {
      updateData['analyticsData'] = analyticsData;
    }

    await docRef.update(updateData);
  }

  /// Generate story chapters based on color analysis and mood
  Future<List<StoryChapter>> _generateChapters({
    required ColorStory colorStory,
    required StoryMood mood,
    required Map<String, dynamic> colorAnalysis,
    required Map<String, dynamic> userPreferences,
  }) async {
    final chapters = <StoryChapter>[];
    final palette = colorStory.palette;

    // Chapter 1: Introduction and Setting the Scene
    chapters.add(StoryChapter(
      id: _generateId(),
      title: 'Setting the Scene',
      content: _generateIntroContent(mood, colorStory.room, colorAnalysis),
      duration: const Duration(minutes: 2),
      interactiveElements: [
        InteractiveElement(
          id: _generateId(),
          type: 'mood_selector',
          title: 'How does this space make you feel?',
          description: 'Select the emotions this color palette evokes',
          data: {
            'options': _getMoodOptions(mood),
            'palette_preview': palette.take(3).map((c) => c.hex).toList(),
          },
          timestamp: const Duration(seconds: 30),
        ),
      ],
      visualEffects: {
        'transition': 'fade_in',
        'background_gradient': _createGradientFromPalette(palette),
      },
    ));

    // Chapter 2: Color Exploration and Psychology
    if (palette.isNotEmpty) {
      chapters.add(StoryChapter(
        id: _generateId(),
        title: 'The Psychology of Color',
        content: _generateColorPsychologyContent(palette, mood),
        duration: const Duration(minutes: 3),
        revealedColors: [palette.first.hex],
        interactiveElements: [
          InteractiveElement(
            id: _generateId(),
            type: 'color_reveal',
            title: 'Discover Your Primary Color',
            description: 'Learn about the emotional impact of your main color',
            data: {
              'color': palette.first.hex,
              'name': palette.first.name ?? 'Your Primary Color',
              'psychology': palette.first.psychology ??
                  _getColorPsychology(palette.first.hex),
            },
            timestamp: const Duration(minutes: 1),
          ),
        ],
        visualEffects: {
          'color_reveal_animation': palette.first.hex,
          'particle_effects': true,
        },
      ));
    }

    // Chapter 3: Room Transformation Journey
    chapters.add(StoryChapter(
      id: _generateId(),
      title: 'Transforming Your Space',
      content: _generateTransformationContent(colorStory.room, mood, palette),
      duration: const Duration(minutes: 4),
      revealedColors: palette.take(3).map((c) => c.hex).toList(),
      interactiveElements: [
        InteractiveElement(
          id: _generateId(),
          type: 'room_transformation',
          title: 'Watch Your Room Transform',
          description: 'See how these colors work together in your space',
          data: {
            'room_type': colorStory.room,
            'before_after': true,
            'palette': palette
                .map((c) => {
                      'hex': c.hex,
                      'role': c.role,
                      'name': c.name,
                    })
                .toList(),
          },
          timestamp: const Duration(minutes: 2),
        ),
      ],
      visualEffects: {
        'room_animation': colorStory.room,
        'color_application': palette.map((c) => c.hex).toList(),
      },
    ));

    // Chapter 4: Practical Application and Tips
    chapters.add(StoryChapter(
      id: _generateId(),
      title: 'Bringing It to Life',
      content: _generatePracticalContent(colorStory.usageGuide, mood),
      duration: const Duration(minutes: 3),
      revealedColors: palette.map((c) => c.hex).toList(),
      interactiveElements: [
        InteractiveElement(
          id: _generateId(),
          type: 'tip_popup',
          title: 'Professional Tips',
          description: 'Expert advice for applying your color palette',
          data: {
            'tips': _generatePracticalTips(colorStory.usageGuide),
            'room_type': colorStory.room,
          },
          timestamp: const Duration(minutes: 1, seconds: 30),
        ),
      ],
      visualEffects: {
        'before_after_comparison': true,
        'tip_animations': true,
      },
    ));

    return chapters;
  }

  /// Analyze color palette for emotional and aesthetic properties
  Map<String, dynamic> _analyzeColorPalette(List<ColorStoryPalette> palette) {
    if (palette.isEmpty) {
      return {
        'dominant_temperature': 'neutral',
        'energy_level': 'moderate',
        'sophistication': 'medium',
        'natural_elements': false,
      };
    }

    final analysis = <String, dynamic>{};

    // Analyze temperature (warm/cool)
    int warmCount = 0;
    int coolCount = 0;

    for (final color in palette) {
      if (_isWarmColor(color.hex)) {
        warmCount++;
      } else {
        coolCount++;
      }
    }

    analysis['dominant_temperature'] = warmCount > coolCount
        ? 'warm'
        : coolCount > warmCount
            ? 'cool'
            : 'neutral';

    // Analyze energy level based on saturation and brightness
    analysis['energy_level'] = _calculateEnergyLevel(palette);

    // Determine sophistication level
    analysis['sophistication'] = _calculateSophistication(palette);

    // Check for natural elements
    analysis['natural_elements'] = _hasNaturalColors(palette);

    return analysis;
  }

  /// Generate content for introduction chapter
  String _generateIntroContent(
      StoryMood mood, String room, Map<String, dynamic> analysis) {
    final moodDescriptions = {
      StoryMood.serene: 'peaceful sanctuary',
      StoryMood.energetic: 'vibrant, dynamic space',
      StoryMood.sophisticated: 'elegant and refined environment',
      StoryMood.cozy: 'warm, inviting retreat',
      StoryMood.fresh: 'clean, airy haven',
      StoryMood.dramatic: 'bold, striking space',
      StoryMood.natural: 'organic, earth-connected environment',
      StoryMood.playful: 'fun, whimsical space',
      StoryMood.minimalist: 'clean, uncluttered sanctuary',
      StoryMood.luxurious: 'opulent, sophisticated environment',
    };

    final moodDesc = moodDescriptions[mood] ?? 'beautiful space';
    final temperature = analysis['dominant_temperature'] ?? 'balanced';

    return '''Welcome to your personal color journey. Today, we'll explore how to transform your ${room.isEmpty ? 'space' : room} into a $moodDesc.

Your carefully selected color palette tells a unique story - one of $temperature tones that ${_getTemperatureDescription(temperature)}. 

As we begin this journey together, imagine stepping into a space that perfectly reflects your personal style and emotional needs. Every color has been chosen not just for its beauty, but for its ability to enhance your daily experience and create the atmosphere you've been dreaming of.

Let's discover the magic hidden within your palette and learn how these colors can transform not just your space, but how you feel within it.''';
  }

  /// Generate color psychology content
  String _generateColorPsychologyContent(
      List<ColorStoryPalette> palette, StoryMood mood) {
    if (palette.isEmpty) return 'Let\'s explore the psychology of color.';

    final primaryColor = palette.first;
    final psychology =
        primaryColor.psychology ?? _getColorPsychology(primaryColor.hex);

    return '''Color is one of the most powerful tools in design, capable of influencing our emotions, energy levels, and even our behavior. Your primary color choice reveals something profound about your aesthetic preferences and emotional needs.

${primaryColor.name ?? 'This beautiful color'} is more than just a visual element - it's a psychological anchor that will set the tone for your entire space. $psychology

When you walk into a room dominated by this color, your mind automatically begins to associate the space with these emotional qualities. This isn't just design theory - it's psychological science applied to create environments that support and enhance your daily life.

As we continue our journey, you'll see how this primary color works in harmony with your supporting palette to create a cohesive emotional experience that extends far beyond simple aesthetics.''';
  }

  /// Generate transformation content
  String _generateTransformationContent(
      String room, StoryMood mood, List<ColorStoryPalette> palette) {
    final roomDescriptions = {
      'living room': 'gathering space where memories are made',
      'bedroom': 'personal sanctuary for rest and rejuvenation',
      'kitchen': 'heart of the home where nourishment begins',
      'bathroom': 'private retreat for self-care and renewal',
      'dining room': 'space for connection and shared experiences',
      'office': 'productive environment for focus and creativity',
    };

    final roomDesc = roomDescriptions[room.toLowerCase()] ?? 'special space';

    return '''Now comes the most exciting part of our journey - watching your vision come to life. Your ${room.isEmpty ? 'space' : room} is about to transform from a simple room into a $roomDesc that reflects your unique personality and supports your lifestyle.

The magic happens when we apply your carefully chosen colors strategically throughout the space. Each color in your palette has a specific role to play:

${_generateRoleDescriptions(palette)}

Watch as these colors work together in perfect harmony, creating visual flow, emotional balance, and functional beauty. This isn't just about making things look pretty - it's about creating an environment that enhances every moment you spend within it.

The transformation you're about to witness demonstrates how thoughtful color application can completely change the feeling and function of a space, turning it into a true reflection of who you are and how you want to live.''';
  }

  /// Generate practical application content
  String _generatePracticalContent(
      List<ColorUsageItem> usageGuide, StoryMood mood) {
    return '''Knowledge is power, but application is transformation. Now that you understand the psychology and vision behind your color palette, let's explore the practical steps to bring this dream to reality.

Professional interior designers follow specific principles when applying color palettes, and these same techniques will ensure your space achieves the perfect balance of beauty and functionality.

The key to successful color application lies in understanding proportion, placement, and purpose. Your palette works best when applied with intention - each color serving a specific function while contributing to the overall emotional narrative of your space.

From preparation and primer selection to final finishing touches, every step in the application process affects the final result. The same color can look dramatically different depending on the surface it's applied to, the lighting conditions, and the colors surrounding it.

Let's walk through the professional techniques that will help you achieve the stunning transformation you've envisioned, ensuring that your space not only looks beautiful but feels exactly the way you intended.''';
  }

  /// Helper methods for content generation
  String _getTemperatureDescription(String temperature) {
    switch (temperature) {
      case 'warm':
        return 'create comfort, energy, and intimacy';
      case 'cool':
        return 'promote calm, focus, and tranquility';
      default:
        return 'provide perfect balance and versatility';
    }
  }

  String _getColorPsychology(String hex) {
    // Simple color psychology based on hex value
    final color = hex.replaceAll('#', '').toLowerCase();
    final r = int.parse(color.substring(0, 2), radix: 16);
    final g = int.parse(color.substring(2, 4), radix: 16);
    final b = int.parse(color.substring(4, 6), radix: 16);

    if (r > g && r > b) {
      return 'This warm color energizes and stimulates, perfect for creating spaces that feel alive and dynamic.';
    } else if (b > r && b > g) {
      return 'This cool color calms and centers, ideal for creating peaceful, focused environments.';
    } else if (g > r && g > b) {
      return 'This natural color grounds and refreshes, bringing the tranquility of nature indoors.';
    } else {
      return 'This balanced color provides versatility and sophistication, adapting beautifully to any mood or occasion.';
    }
  }

  String _generateRoleDescriptions(List<ColorStoryPalette> palette) {
    final descriptions = <String>[];

    for (final color in palette.take(4)) {
      final role = color.role;
      final name = color.name ?? 'Color ${palette.indexOf(color) + 1}';

      switch (role.toLowerCase()) {
        case 'main':
          descriptions.add(
              '• $name serves as your foundation, covering the largest surfaces and setting the overall mood');
          break;
        case 'accent':
          descriptions.add(
              '• $name adds personality and visual interest through accessories and focal points');
          break;
        case 'trim':
          descriptions.add(
              '• $name defines and frames your space, creating clean lines and architectural interest');
          break;
        case 'ceiling':
          descriptions.add(
              '• $name draws the eye upward, creating height and atmospheric depth');
          break;
        default:
          descriptions.add(
              '• $name brings balance and harmony to complete your color story');
      }
    }

    return descriptions.join('\n');
  }

  List<String> _generatePracticalTips(List<ColorUsageItem> usageGuide) {
    final tips = <String>[
      'Always test colors in different lighting conditions before final application',
      'Use high-quality primer appropriate for your surface material',
      'Apply colors in thin, even coats for the best finish and color accuracy',
      'Consider the sheen level - matte for low-traffic areas, satin for high-touch surfaces',
    ];

    // Add specific tips based on usage guide
    for (final item in usageGuide.take(3)) {
      if (item.howToUse.isNotEmpty) {
        tips.add(item.howToUse);
      }
    }

    return tips;
  }

  /// Utility methods
  bool _isWarmColor(String hex) {
    final color = hex.replaceAll('#', '');
    final r = int.parse(color.substring(0, 2), radix: 16);
    final g = int.parse(color.substring(2, 4), radix: 16);
    final b = int.parse(color.substring(4, 6), radix: 16);

    return (r > b) && (r + g > b * 1.5);
  }

  String _calculateEnergyLevel(List<ColorStoryPalette> palette) {
    // Simplified energy calculation based on saturation
    return palette.length > 3
        ? 'high'
        : palette.length > 1
            ? 'moderate'
            : 'low';
  }

  String _calculateSophistication(List<ColorStoryPalette> palette) {
    // Simplified sophistication based on palette complexity
    return palette.any((c) => c.role == 'trim') ? 'high' : 'medium';
  }

  bool _hasNaturalColors(List<ColorStoryPalette> palette) {
    // Check for earth tones and natural colors
    return palette.any((c) =>
        c.name?.toLowerCase().contains('earth') == true ||
        c.name?.toLowerCase().contains('wood') == true ||
        c.name?.toLowerCase().contains('stone') == true);
  }

  Map<String, String> _createGradientFromPalette(
      List<ColorStoryPalette> palette) {
    if (palette.isEmpty) return {'start': '#6366F1', 'end': '#8B5CF6'};
    if (palette.length == 1) {
      return {'start': palette[0].hex, 'end': palette[0].hex};
    }

    return {
      'start': palette[0].hex,
      'end': palette[1].hex,
    };
  }

  List<String> _getMoodOptions(StoryMood mood) {
    final options = {
      StoryMood.serene: ['Peaceful', 'Calming', 'Tranquil', 'Relaxing'],
      StoryMood.energetic: ['Vibrant', 'Dynamic', 'Exciting', 'Invigorating'],
      StoryMood.sophisticated: ['Elegant', 'Refined', 'Luxurious', 'Polished'],
      StoryMood.cozy: ['Warm', 'Comfortable', 'Intimate', 'Inviting'],
      StoryMood.fresh: ['Clean', 'Airy', 'Light', 'Refreshing'],
    };

    return options[mood] ?? ['Beautiful', 'Inspiring', 'Harmonious', 'Perfect'];
  }

  String _generateTitle(StoryMood mood, Map<String, dynamic> analysis) {
    final templates = {
      StoryMood.serene: 'A Peaceful Color Journey',
      StoryMood.energetic: 'Vibrant Spaces, Bold Choices',
      StoryMood.sophisticated: 'Elegance in Every Hue',
      StoryMood.cozy: 'Creating Your Cozy Haven',
      StoryMood.fresh: 'Fresh Beginnings, Beautiful Spaces',
    };

    return templates[mood] ?? 'Your Personal Color Story';
  }

  String _generateDescription(StoryMood mood, ColorStory colorStory) {
    return 'Discover the story behind your ${colorStory.room} color palette and learn how to create a ${mood.name} atmosphere that reflects your personal style.';
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        _random.nextInt(9999).toString().padLeft(4, '0');
  }
}
