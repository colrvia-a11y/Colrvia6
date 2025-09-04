import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/immersive_story_context.dart';
import '../models/story_experience.dart';

/// Revolutionary AI-powered narrative generation service
class ImmersiveNarrativeEngine {
  static final ImmersiveNarrativeEngine _instance =
      ImmersiveNarrativeEngine._internal();
  factory ImmersiveNarrativeEngine() => _instance;
  ImmersiveNarrativeEngine._internal();

  final Random _random = Random();

  // Emotional color mappings for narrative generation
  final Map<String, List<String>> _colorEmotions = {
    'blue': ['calm', 'peaceful', 'introspective', 'serene', 'vast', 'deep'],
    'green': ['balanced', 'natural', 'growth', 'renewal', 'harmony', 'fresh'],
    'red': ['passionate', 'energetic', 'bold', 'warm', 'powerful', 'intense'],
    'yellow': [
      'joyful',
      'optimistic',
      'creative',
      'warm',
      'illuminating',
      'uplifting'
    ],
    'purple': [
      'mysterious',
      'sophisticated',
      'creative',
      'luxurious',
      'spiritual',
      'royal'
    ],
    'orange': [
      'enthusiastic',
      'warm',
      'welcoming',
      'energetic',
      'social',
      'vibrant'
    ],
    'pink': [
      'nurturing',
      'gentle',
      'romantic',
      'soft',
      'compassionate',
      'playful'
    ],
    'brown': [
      'grounded',
      'stable',
      'natural',
      'authentic',
      'reliable',
      'earthy'
    ],
    'gray': [
      'sophisticated',
      'balanced',
      'timeless',
      'calming',
      'elegant',
      'neutral'
    ],
    'black': [
      'dramatic',
      'powerful',
      'sophisticated',
      'mysterious',
      'bold',
      'elegant'
    ],
    'white': ['pure', 'clean', 'peaceful', 'spacious', 'fresh', 'minimalist'],
  };

  // Narrative templates for different story phases
  final Map<StoryJourneyPhase, List<String>> _narrativeTemplates = {
    StoryJourneyPhase.spaceAwakens: [
      "Imagine stepping into your {roomType} at this very moment. The {primaryColor} walls seem to breathe with anticipation, as if they've been waiting just for you. This isn't just decoration - this is emotional architecture designed for your {lifestyle} life.",
      "Your space whispers a secret as you enter. The {primaryColor} tones create an invisible embrace, while the {accentColor} accents dance like gentle flames of possibility. Here, in this sanctuary you're creating, every color has chosen you as much as you've chosen them.",
      "Picture this: it's {timeOfDay}, and as you step into your transformed {roomType}, something magical happens. The {primaryColor} hues don't just reflect light - they reflect your soul's deepest need for {mood}.",
    ],
    StoryJourneyPhase.morningLight: [
      "As dawn breaks through your windows, your {primaryColor} walls catch the first golden rays. This is how your day begins - not with harsh alarms, but with the gentle awakening that only your perfect color palette can provide.",
      "Morning light dances across your {accentColor} accents, creating a symphony of shadows and warmth. Your breakfast tastes different here, more intentional, more yours.",
      "The {primaryColor} that surrounds you doesn't just greet the morning - it transforms it. Each ray of sunlight becomes a brushstroke, painting your day with the emotions you need most.",
    ],
    StoryJourneyPhase.middayEnergy: [
      "When the afternoon sun reaches its peak, your {primaryColor} palette reveals its true power. This isn't just background - it's your productivity partner, energizing your work and focus.",
      "Your {accentColor} details catch the midday light like gemstones, reminding you that even in your busiest moments, beauty surrounds you. This is how color supports your {lifestyle} lifestyle.",
      "The gentle energy of your {primaryColor} walls creates the perfect backdrop for your most important work. Here, surrounded by intentional color, your creativity flows effortlessly.",
    ],
    StoryJourneyPhase.eveningEmbrace: [
      "As evening settles, your {primaryColor} sanctuary transforms once again. The warm glow of your lamps turns these walls into a cocoon of {mood}, washing away the day's tensions.",
      "Your {accentColor} accents now glow like embers, creating the perfect atmosphere for unwinding. This is how color helps you transition from day to night, from doing to being.",
      "In the gentle twilight, your space doesn't just shelter you - it holds you. The {primaryColor} tones seem to exhale with you, creating the perfect end to your day.",
    ],
    StoryJourneyPhase.personalReflection: [
      "These colors didn't choose you by accident. Your {primaryColor} reflects your need for {emotion}, while your {accentColor} speaks to your desire for {secondaryEmotion}. This palette is your emotional fingerprint.",
      "Look around your transformed space and see yourself reflected in every hue. The {primaryColor} that draws you so deeply mirrors your own {personalityTrait}, while the {accentColor} celebrates your {secondaryTrait}.",
      "This is more than interior design - this is self-discovery through color. Your palette tells the story of who you are and who you're becoming. Every shade is a chapter in your personal evolution.",
    ],
  };

  /// Generate a complete immersive story experience
  Future<StoryExperience> generateImmersiveStory({
    required ColorStoryContext context,
    required PersonalTouch personalTouch,
    required StoryCategory category,
    required String userId,
  }) async {
    try {
      final storyId = _generateStoryId();
      final chapters = await _generateImmersiveChapters(
        context: context,
        personalTouch: personalTouch,
        category: category,
      );

      final totalDuration = chapters.fold<Duration>(
        Duration.zero,
        (sum, chapter) => sum + chapter.duration,
      );

      final title =
          _generatePersonalizedTitle(context, personalTouch, category);
      final description = _generateImmersiveDescription(context, category);

      return StoryExperience(
        id: storyId,
        userId: userId,
        title: title,
        description: description,
        mood: _mapContextToMood(context.mood),
        chapters: chapters,
        totalDuration: totalDuration,
        userPreferences: context.toStoryParameters(),
        lastPlayedAt: DateTime.now(),
        isCustomGenerated: true,
      );
    } catch (e) {
      debugPrint('Error generating immersive story: $e');
      rethrow;
    }
  }

  /// Generate immersive chapters with cinematic storytelling
  Future<List<StoryChapter>> _generateImmersiveChapters({
    required ColorStoryContext context,
    required PersonalTouch personalTouch,
    required StoryCategory category,
  }) async {
    final chapters = <StoryChapter>[];

    // Phase 1: Space Awakens (Cinematic Introduction)
    chapters.add(await _createCinematicChapter(
      phase: StoryJourneyPhase.spaceAwakens,
      context: context,
      personalTouch: personalTouch,
      category: category,
      duration: const Duration(minutes: 3),
    ));

    // Phase 2: Morning Light (Temporal Journey)
    chapters.add(await _createCinematicChapter(
      phase: StoryJourneyPhase.morningLight,
      context: context,
      personalTouch: personalTouch,
      category: category,
      duration: const Duration(minutes: 2, seconds: 30),
    ));

    // Phase 3: Midday Energy (Productivity Focus)
    chapters.add(await _createCinematicChapter(
      phase: StoryJourneyPhase.middayEnergy,
      context: context,
      personalTouch: personalTouch,
      category: category,
      duration: const Duration(minutes: 3, seconds: 30),
    ));

    // Phase 4: Evening Embrace (Emotional Connection)
    chapters.add(await _createCinematicChapter(
      phase: StoryJourneyPhase.eveningEmbrace,
      context: context,
      personalTouch: personalTouch,
      category: category,
      duration: const Duration(minutes: 4),
    ));

    // Phase 5: Personal Reflection (Deep Connection)
    chapters.add(await _createCinematicChapter(
      phase: StoryJourneyPhase.personalReflection,
      context: context,
      personalTouch: personalTouch,
      category: category,
      duration: const Duration(minutes: 5),
    ));

    return chapters;
  }

  /// Create a cinematic chapter with advanced storytelling
  Future<StoryChapter> _createCinematicChapter({
    required StoryJourneyPhase phase,
    required ColorStoryContext context,
    required PersonalTouch personalTouch,
    required StoryCategory category,
    required Duration duration,
  }) async {
    final chapterId = _generateChapterId();
    final primaryColor =
        context.palette.isNotEmpty ? context.palette.first : Colors.blue;
    final accentColor =
        context.palette.length > 1 ? context.palette[1] : Colors.grey;

    // Generate personalized narrative content
    final content = _generatePersonalizedNarrative(
      phase: phase,
      context: context,
      personalTouch: personalTouch,
      category: category,
    );

    // Create interactive elements based on phase
    final interactiveElements = _createInteractiveElements(
      phase: phase,
      context: context,
      duration: duration,
    );

    // Generate visual effects for cinematic experience
    final visualEffects = _createVisualEffects(
      phase: phase,
      primaryColor: primaryColor,
      accentColor: accentColor,
      context: context,
    );

    return StoryChapter(
      id: chapterId,
      title: _getPhaseTitle(phase, personalTouch),
      content: content,
      duration: duration,
      interactiveElements: interactiveElements,
      revealedColors: _getRevealedColors(phase, context),
      visualEffects: visualEffects,
    );
  }

  /// Generate personalized narrative with emotional depth
  String _generatePersonalizedNarrative({
    required StoryJourneyPhase phase,
    required ColorStoryContext context,
    required PersonalTouch personalTouch,
    required StoryCategory category,
  }) {
    final templates = _narrativeTemplates[phase] ?? [];
    if (templates.isEmpty) return 'Your color journey continues...';

    final template = templates[_random.nextInt(templates.length)];
    final primaryColor =
        context.palette.isNotEmpty ? context.palette.first : Colors.blue;
    final accentColor =
        context.palette.length > 1 ? context.palette[1] : Colors.grey;

    // Get color emotions for narrative depth
    final primaryEmotions = _getColorEmotions(primaryColor);
    final accentEmotions = _getColorEmotions(accentColor);

    return template
        .replaceAll('{roomType}', context.roomType)
        .replaceAll('{primaryColor}', _getColorName(primaryColor))
        .replaceAll('{accentColor}', _getColorName(accentColor))
        .replaceAll('{lifestyle}', context.lifestyle)
        .replaceAll('{mood}', context.mood)
        .replaceAll('{timeOfDay}', context.timeOfDay)
        .replaceAll('{emotion}',
            primaryEmotions.isNotEmpty ? primaryEmotions.first : 'balance')
        .replaceAll('{secondaryEmotion}',
            accentEmotions.isNotEmpty ? accentEmotions.first : 'harmony')
        .replaceAll('{personalityTrait}', _getPersonalityTrait(primaryColor))
        .replaceAll('{secondaryTrait}', _getPersonalityTrait(accentColor));
  }

  /// Create interactive elements for immersive experience
  List<InteractiveElement> _createInteractiveElements({
    required StoryJourneyPhase phase,
    required ColorStoryContext context,
    required Duration duration,
  }) {
    final elements = <InteractiveElement>[];

    switch (phase) {
      case StoryJourneyPhase.spaceAwakens:
        elements.add(InteractiveElement(
          id: _generateElementId(),
          type: 'color_breathing',
          title: 'Feel Your Colors Breathe',
          description:
              'Place your hand on your heart and breathe with your palette',
          data: {
            'colors': context.palette
                .map((c) => '#${c.toARGB32().toRadixString(16).substring(2)}')
                .toList(),
            'breathing_pattern': 'calm',
            'duration': 30,
          },
          timestamp: Duration(seconds: duration.inSeconds ~/ 3),
        ));
        break;

      case StoryJourneyPhase.morningLight:
        elements.add(InteractiveElement(
          id: _generateElementId(),
          type: 'light_simulation',
          title: 'Morning Light Discovery',
          description: 'See how natural light transforms your colors',
          data: {
            'light_stages': ['dawn', 'morning', 'bright'],
            'color_changes': true,
            'room_type': context.roomType,
          },
          timestamp: Duration(seconds: duration.inSeconds ~/ 2),
        ));
        break;

      case StoryJourneyPhase.middayEnergy:
        elements.add(InteractiveElement(
          id: _generateElementId(),
          type: 'productivity_zone',
          title: 'Your Focus Colors',
          description: 'Discover which colors enhance your productivity',
          data: {
            'lifestyle': context.lifestyle,
            'optimal_colors': context.palette
                .take(3)
                .map((c) => '#${c.toARGB32().toRadixString(16).substring(2)}')
                .toList(),
            'focus_tips': true,
          },
          timestamp: Duration(seconds: duration.inSeconds ~/ 3),
        ));
        break;

      case StoryJourneyPhase.eveningEmbrace:
        elements.add(InteractiveElement(
          id: _generateElementId(),
          type: 'twilight_mood',
          title: 'Evening Transformation',
          description: 'Watch your space transform for relaxation',
          data: {
            'lighting': 'warm',
            'color_temperature': 'soft',
            'ambiance': context.mood,
          },
          timestamp: Duration(seconds: duration.inSeconds ~/ 4),
        ));
        break;

      case StoryJourneyPhase.personalReflection:
        elements.add(InteractiveElement(
          id: _generateElementId(),
          type: 'color_personality',
          title: 'Your Color Soul',
          description: 'Discover the deeper meaning of your color choices',
          data: {
            'personality_analysis': true,
            'color_memories': context.colorMemories,
            'emotional_profile': true,
          },
          timestamp: Duration(seconds: duration.inSeconds ~/ 2),
        ));
        break;
    }

    return elements;
  }

  /// Create visual effects for cinematic experience
  Map<String, dynamic> _createVisualEffects({
    required StoryJourneyPhase phase,
    required Color primaryColor,
    required Color accentColor,
    required ColorStoryContext context,
  }) {
    final effects = <String, dynamic>{};

    switch (phase) {
      case StoryJourneyPhase.spaceAwakens:
        effects.addAll({
          'transition': 'cinematic_fade',
          'parallax_layers': 3,
          'color_bloom': primaryColor.toARGB32(),
          'particle_system': true,
          'entrance_animation': 'grand_reveal',
        });
        break;

      case StoryJourneyPhase.morningLight:
        effects.addAll({
          'light_simulation': 'golden_hour',
          'shadow_play': true,
          'color_temperature_shift': 'warm_to_bright',
          'sunbeam_effects': true,
        });
        break;

      case StoryJourneyPhase.middayEnergy:
        effects.addAll({
          'energy_particles': true,
          'focus_pulse': primaryColor.toARGB32(),
          'productivity_aura': accentColor.toARGB32(),
          'dynamic_lighting': 'bright_focus',
        });
        break;

      case StoryJourneyPhase.eveningEmbrace:
        effects.addAll({
          'twilight_gradient': true,
          'soft_glow': primaryColor.toARGB32(),
          'ambient_particles': 'floating',
          'relaxation_waves': accentColor.toARGB32(),
        });
        break;

      case StoryJourneyPhase.personalReflection:
        effects.addAll({
          'soul_mirror': true,
          'color_memories': 'flashback',
          'personality_aura': primaryColor.toARGB32(),
          'deep_connection': 'heartbeat_sync',
        });
        break;
    }

    return effects;
  }

  // Helper methods
  String _generateStoryId() =>
      'immersive_${DateTime.now().millisecondsSinceEpoch}';
  String _generateChapterId() =>
      'chapter_${DateTime.now().microsecondsSinceEpoch}';
  String _generateElementId() =>
      'element_${DateTime.now().microsecondsSinceEpoch}';

  List<String> _getColorEmotions(Color color) {
    final colorName = _getColorName(color).toLowerCase();
    return _colorEmotions[colorName] ?? ['beautiful', 'inspiring'];
  }

  String _getColorName(Color color) {
    final hsl = HSLColor.fromColor(color);
    final hue = hsl.hue;

    if (hue < 30) return 'red';
    if (hue < 60) return 'orange';
    if (hue < 90) return 'yellow';
    if (hue < 150) return 'green';
    if (hue < 210) return 'blue';
    if (hue < 270) return 'purple';
    if (hue < 330) return 'pink';
    return 'red';
  }

  String _getPersonalityTrait(Color color) {
    final emotions = _getColorEmotions(color);
    return emotions.isNotEmpty
        ? emotions[_random.nextInt(emotions.length)]
        : 'unique';
  }

  StoryMood _mapContextToMood(String moodString) {
    switch (moodString.toLowerCase()) {
      case 'calm':
      case 'peaceful':
        return StoryMood.serene;
      case 'energetic':
      case 'vibrant':
        return StoryMood.energetic;
      case 'elegant':
      case 'sophisticated':
        return StoryMood.sophisticated;
      case 'cozy':
      case 'warm':
        return StoryMood.cozy;
      case 'fresh':
      case 'clean':
        return StoryMood.fresh;
      case 'dramatic':
      case 'bold':
        return StoryMood.dramatic;
      case 'natural':
      case 'organic':
        return StoryMood.natural;
      case 'playful':
      case 'fun':
        return StoryMood.playful;
      case 'minimal':
      case 'simple':
        return StoryMood.minimalist;
      case 'luxury':
      case 'rich':
        return StoryMood.luxurious;
      default:
        return StoryMood.serene;
    }
  }

  String _generatePersonalizedTitle(ColorStoryContext context,
      PersonalTouch personalTouch, StoryCategory category) {
    final primaryColor = _getColorName(
        context.palette.isNotEmpty ? context.palette.first : Colors.blue);
    final mood = context.mood;

    final titleTemplates = [
      "Your ${primaryColor.capitalize()} Journey to $mood",
      "${personalTouch.userName.isNotEmpty ? "${personalTouch.userName}'s" : "Your"} $mood Sanctuary",
      "The Soul of ${primaryColor.capitalize()}: A $mood Story",
      "Discovering $mood Through ${primaryColor.capitalize()}",
    ];

    return titleTemplates[_random.nextInt(titleTemplates.length)];
  }

  String _generateImmersiveDescription(
      ColorStoryContext context, StoryCategory category) {
    final primaryColor = _getColorName(
        context.palette.isNotEmpty ? context.palette.first : Colors.blue);

    switch (category) {
      case StoryCategory.emotionalJourney:
        return "Experience how $primaryColor transforms your emotional landscape, creating a ${context.mood} sanctuary that speaks to your soul.";
      case StoryCategory.practicalGuide:
        return "Discover the practical magic of your $primaryColor palette and how to bring this ${context.mood} vision to life in your ${context.roomType}.";
      case StoryCategory.culturalExplorer:
        return "Journey through the cultural significance of $primaryColor, exploring its global meanings and seasonal connections.";
      case StoryCategory.scienceBehind:
        return "Uncover the fascinating psychology behind your $primaryColor palette and its ${context.mood} effects on your daily life.";
    }
  }

  String _getPhaseTitle(StoryJourneyPhase phase, PersonalTouch personalTouch) {
    switch (phase) {
      case StoryJourneyPhase.spaceAwakens:
        return "${personalTouch.userName.isNotEmpty ? "${personalTouch.userName}'s" : "Your"} Space Awakens";
      case StoryJourneyPhase.morningLight:
        return "Morning Light Magic";
      case StoryJourneyPhase.middayEnergy:
        return "Midday Energy Flow";
      case StoryJourneyPhase.eveningEmbrace:
        return "Evening's Gentle Embrace";
      case StoryJourneyPhase.personalReflection:
        return "Your Color Soul Revealed";
    }
  }

  List<String> _getRevealedColors(
      StoryJourneyPhase phase, ColorStoryContext context) {
    switch (phase) {
      case StoryJourneyPhase.spaceAwakens:
        return context.palette
            .take(1)
            .map((c) => '#${c.toARGB32().toRadixString(16).substring(2)}')
            .toList();
      case StoryJourneyPhase.morningLight:
        return context.palette
            .take(2)
            .map((c) => '#${c.toARGB32().toRadixString(16).substring(2)}')
            .toList();
      case StoryJourneyPhase.middayEnergy:
        return context.palette
            .take(3)
            .map((c) => '#${c.toARGB32().toRadixString(16).substring(2)}')
            .toList();
      case StoryJourneyPhase.eveningEmbrace:
        return context.palette
            .take(4)
            .map((c) => '#${c.toARGB32().toRadixString(16).substring(2)}')
            .toList();
      case StoryJourneyPhase.personalReflection:
        return context.palette
            .map((c) => '#${c.toARGB32().toRadixString(16).substring(2)}')
            .toList();
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
