import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents different emotional and aesthetic moods for color stories
enum StoryMood {
  serene, // Calming, peaceful environments
  energetic, // Vibrant, dynamic spaces
  sophisticated, // Elegant, refined atmospheres
  cozy, // Warm, intimate settings
  fresh, // Clean, airy environments
  dramatic, // Bold, high-contrast designs
  natural, // Earth-tones, organic feels
  playful, // Fun, whimsical spaces
  minimalist, // Clean, simple aesthetics
  luxurious, // Rich, opulent environments
}

/// Interactive elements within a story chapter
class InteractiveElement {
  final String id;
  final String
      type; // 'color_reveal', 'room_transformation', 'mood_selector', 'tip_popup'
  final String title;
  final String description;
  final Map<String, dynamic> data; // Flexible data for different element types
  final Duration timestamp; // When this element appears in the story
  final bool isCompleted;

  InteractiveElement({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.data,
    required this.timestamp,
    this.isCompleted = false,
  });

  factory InteractiveElement.fromJson(Map<String, dynamic> json) {
    return InteractiveElement(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      timestamp: Duration(milliseconds: json['timestamp'] ?? 0),
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'description': description,
      'data': data,
      'timestamp': timestamp.inMilliseconds,
      'isCompleted': isCompleted,
    };
  }

  InteractiveElement copyWith({
    bool? isCompleted,
    Map<String, dynamic>? data,
  }) {
    return InteractiveElement(
      id: id,
      type: type,
      title: title,
      description: description,
      data: data ?? this.data,
      timestamp: timestamp,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// A chapter within a color story experience
class StoryChapter {
  final String id;
  final String title;
  final String content;
  final String? audioUrl;
  final String? imageUrl;
  final Duration duration;
  final List<InteractiveElement> interactiveElements;
  final List<String> revealedColors; // Color hex codes revealed in this chapter
  final Map<String, dynamic> visualEffects; // Animation and transition data

  StoryChapter({
    required this.id,
    required this.title,
    required this.content,
    this.audioUrl,
    this.imageUrl,
    required this.duration,
    this.interactiveElements = const [],
    this.revealedColors = const [],
    this.visualEffects = const {},
  });

  factory StoryChapter.fromJson(Map<String, dynamic> json) {
    return StoryChapter(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      audioUrl: json['audioUrl'],
      imageUrl: json['imageUrl'],
      duration: Duration(milliseconds: json['duration'] ?? 0),
      interactiveElements: (json['interactiveElements'] as List<dynamic>? ?? [])
          .map((e) => InteractiveElement.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      revealedColors: List<String>.from(json['revealedColors'] ?? []),
      visualEffects: Map<String, dynamic>.from(json['visualEffects'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'audioUrl': audioUrl,
      'imageUrl': imageUrl,
      'duration': duration.inMilliseconds,
      'interactiveElements':
          interactiveElements.map((e) => e.toJson()).toList(),
      'revealedColors': revealedColors,
      'visualEffects': visualEffects,
    };
  }
}

/// Enhanced immersive color story experience
class StoryExperience {
  final String id;
  final String userId;
  final String title;
  final String description;
  final StoryMood mood;
  final List<StoryChapter> chapters;
  final Duration totalDuration;
  final Map<String, dynamic> userPreferences; // Personalization settings
  final DateTime lastPlayedAt;
  final double completionProgress; // 0.0 to 1.0
  final List<String> completedChapterIds;
  final Map<String, dynamic> analyticsData; // Engagement tracking
  final bool isCustomGenerated; // True if generated from user's palette
  final String?
      sourceColorStoryId; // Reference to original ColorStory if applicable

  StoryExperience({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.mood,
    required this.chapters,
    required this.totalDuration,
    this.userPreferences = const {},
    required this.lastPlayedAt,
    this.completionProgress = 0.0,
    this.completedChapterIds = const [],
    this.analyticsData = const {},
    this.isCustomGenerated = false,
    this.sourceColorStoryId,
  });

  factory StoryExperience.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoryExperience.fromJson(data)..copyWith(id: doc.id);
  }

  factory StoryExperience.fromJson(Map<String, dynamic> json) {
    return StoryExperience(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      mood: StoryMood.values.firstWhere(
        (m) => m.name == (json['mood'] ?? 'serene'),
        orElse: () => StoryMood.serene,
      ),
      chapters: (json['chapters'] as List<dynamic>? ?? [])
          .map((c) => StoryChapter.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
      totalDuration: Duration(milliseconds: json['totalDuration'] ?? 0),
      userPreferences: Map<String, dynamic>.from(json['userPreferences'] ?? {}),
      lastPlayedAt: json['lastPlayedAt'] != null
          ? (json['lastPlayedAt'] as Timestamp).toDate()
          : DateTime.now(),
      completionProgress: (json['completionProgress'] ?? 0.0).toDouble(),
      completedChapterIds: List<String>.from(json['completedChapterIds'] ?? []),
      analyticsData: Map<String, dynamic>.from(json['analyticsData'] ?? {}),
      isCustomGenerated: json['isCustomGenerated'] ?? false,
      sourceColorStoryId: json['sourceColorStoryId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'mood': mood.name,
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'totalDuration': totalDuration.inMilliseconds,
      'userPreferences': userPreferences,
      'lastPlayedAt': Timestamp.fromDate(lastPlayedAt),
      'completionProgress': completionProgress,
      'completedChapterIds': completedChapterIds,
      'analyticsData': analyticsData,
      'isCustomGenerated': isCustomGenerated,
      'sourceColorStoryId': sourceColorStoryId,
    };
  }

  StoryExperience copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    StoryMood? mood,
    List<StoryChapter>? chapters,
    Duration? totalDuration,
    Map<String, dynamic>? userPreferences,
    DateTime? lastPlayedAt,
    double? completionProgress,
    List<String>? completedChapterIds,
    Map<String, dynamic>? analyticsData,
    bool? isCustomGenerated,
    String? sourceColorStoryId,
  }) {
    return StoryExperience(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      mood: mood ?? this.mood,
      chapters: chapters ?? this.chapters,
      totalDuration: totalDuration ?? this.totalDuration,
      userPreferences: userPreferences ?? this.userPreferences,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      completionProgress: completionProgress ?? this.completionProgress,
      completedChapterIds: completedChapterIds ?? this.completedChapterIds,
      analyticsData: analyticsData ?? this.analyticsData,
      isCustomGenerated: isCustomGenerated ?? this.isCustomGenerated,
      sourceColorStoryId: sourceColorStoryId ?? this.sourceColorStoryId,
    );
  }

  /// Check if a specific chapter is completed
  bool isChapterCompleted(String chapterId) {
    return completedChapterIds.contains(chapterId);
  }

  /// Get the next chapter to play
  StoryChapter? get nextChapter {
    for (final chapter in chapters) {
      if (!isChapterCompleted(chapter.id)) {
        return chapter;
      }
    }
    return null; // All chapters completed
  }

  /// Calculate completion percentage as integer
  int get completionPercentage {
    return (completionProgress * 100).round();
  }

  /// Check if the entire story experience is completed
  bool get isCompleted {
    return completionProgress >= 1.0 ||
        completedChapterIds.length == chapters.length;
  }
}
