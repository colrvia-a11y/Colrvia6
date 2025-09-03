import 'package:flutter/material.dart';

/// Advanced context for AI-powered narrative generation
class ColorStoryContext {
  final List<Color> palette;
  final String roomType;
  final String lifestyle;
  final String mood;
  final String timeOfDay;
  final String personalStyle;
  final List<String> colorMemories;
  final String currentSeason;
  final String location;
  final List<Color> previousPalettes;

  const ColorStoryContext({
    required this.palette,
    required this.roomType,
    required this.lifestyle,
    required this.mood,
    required this.timeOfDay,
    this.personalStyle = 'balanced',
    this.colorMemories = const [],
    this.currentSeason = 'spring',
    this.location = 'urban',
    this.previousPalettes = const [],
  });

  /// Generate personalized story parameters
  Map<String, dynamic> toStoryParameters() {
    return {
      'palette': palette
          .map((c) => '#${c.toARGB32().toRadixString(16).substring(2)}')
          .toList(),
      'roomType': roomType,
      'lifestyle': lifestyle,
      'mood': mood,
      'timeOfDay': timeOfDay,
      'personalStyle': personalStyle,
      'colorMemories': colorMemories,
      'currentSeason': currentSeason,
      'location': location,
      'previousPalettes': previousPalettes
          .map((c) => '#${c.toARGB32().toRadixString(16).substring(2)}')
          .toList(),
    };
  }
}

/// Enhanced story structure with branching narratives
enum StoryJourneyPhase {
  spaceAwakens, // Introduction - "Your Space Awakens"
  morningLight, // "Morning Light" - How colors feel at breakfast
  middayEnergy, // "Midday Energy" - How they support productivity
  eveningEmbrace, // "Evening Embrace" - How they help you unwind
  personalReflection, // "Personal Reflection" - Why these colors chose YOU
}

/// Multi-sensory story elements
class SensoryExperience {
  final String visualLayer;
  final String? audioUrl;
  final String? ambientSoundscape;
  final List<String> soundEffects;
  final Map<String, dynamic> hapticPatterns;
  final Duration transitionDuration;

  const SensoryExperience({
    required this.visualLayer,
    this.audioUrl,
    this.ambientSoundscape,
    this.soundEffects = const [],
    this.hapticPatterns = const {},
    this.transitionDuration = const Duration(milliseconds: 1500),
  });
}

/// Personal connection engine for customization
class PersonalTouch {
  final String userName;
  final List<String> preferences;
  final String currentSeason;
  final String location;
  final List<Color> previousPalettes;
  final Map<String, dynamic> emotionalProfile;
  final DateTime lastInteraction;

  const PersonalTouch({
    required this.userName,
    this.preferences = const [],
    this.currentSeason = 'spring',
    this.location = 'urban',
    this.previousPalettes = const [],
    this.emotionalProfile = const {},
    required this.lastInteraction,
  });

  /// Generate personalized narrative voice
  String getPersonalizedGreeting() {
    final hour = DateTime.now().hour;
    String timeGreeting;

    if (hour < 12) {
      timeGreeting = "Good morning";
    } else if (hour < 17) {
      timeGreeting = "Good afternoon";
    } else {
      timeGreeting = "Good evening";
    }

    return "$timeGreeting, ${userName.isNotEmpty ? userName : 'beautiful soul'}";
  }

  /// Create adaptive story elements based on user preferences
  List<String> getAdaptiveElements() {
    final elements = <String>[];

    if (preferences.contains('loves natural light')) {
      elements.add('natural_light_simulation');
    }
    if (preferences.contains('works from home')) {
      elements.add('productivity_focus');
    }
    if (preferences.contains('evening person')) {
      elements.add('twilight_atmosphere');
    }

    return elements;
  }
}

/// Interactive story categories for different experiences
enum StoryCategory {
  emotionalJourney, // How colors make you feel
  practicalGuide, // Best rooms, lighting, furniture
  culturalExplorer, // Historical significance, global inspirations
  scienceBehind, // Psychology in accessible language
}

/// Cinematic transition types for immersive experience
enum CinematicTransition {
  fadeToColor,
  parallaxDrift,
  colorBloom,
  roomMorph,
  lightShift,
  memoryFlash,
  seasonChange,
  moodFlow,
}

/// Story beat for narrative pacing
class StoryBeat {
  final String id;
  final Duration timestamp;
  final String emotion;
  final List<Color> colors;
  final CinematicTransition transition;
  final Map<String, dynamic> interactionData;

  const StoryBeat({
    required this.id,
    required this.timestamp,
    required this.emotion,
    required this.colors,
    this.transition = CinematicTransition.fadeToColor,
    this.interactionData = const {},
  });
}

/// Enhanced color personality system
class ColorPersonality {
  final Color color;
  final String name;
  final String personality;
  final String voiceDescription;
  final List<String> memoryTriggers;
  final Map<String, String> culturalMeanings;
  final String scientificEffect;

  const ColorPersonality({
    required this.color,
    required this.name,
    required this.personality,
    required this.voiceDescription,
    this.memoryTriggers = const [],
    this.culturalMeanings = const {},
    required this.scientificEffect,
  });

  /// Generate immersive color description
  String getImmersiveDescription() {
    return "Your $name feels like $voiceDescription. It doesn't just $scientificEffect - it ${memoryTriggers.isNotEmpty ? memoryTriggers.first : 'embraces your space with intention'}.";
  }
}
