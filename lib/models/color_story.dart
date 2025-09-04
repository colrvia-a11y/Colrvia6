import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ColorUsageItem {
  final String role,
      hex,
      name,
      brandName,
      code,
      surface,
      finishRecommendation,
      sheen,
      howToUse;
  ColorUsageItem.fromMap(Map<String, dynamic> m)
      : role = m['role'],
        hex = m['hex'],
        name = m['name'],
        brandName = m['brandName'],
        code = m['code'],
        surface = m['surface'],
        finishRecommendation = m['finishRecommendation'],
        sheen = m['sheen'],
        howToUse = m['howToUse'];
}

// Color Story palette item
class ColorStoryPalette {
  final String role; // main, accent, trim, ceiling, door, cabinet
  final String hex;
  final String? paintId;
  final String? brandName;
  final String? name;
  final String? code;
  final String? psychology;
  final String? usageTips;

  ColorStoryPalette({
    required this.role,
    required this.hex,
    this.paintId,
    this.brandName,
    this.name,
    this.code,
    this.psychology,
    this.usageTips,
  });

  factory ColorStoryPalette.fromJson(Map<String, dynamic> json) {
    return ColorStoryPalette(
      role: json['role'] ?? 'main',
      hex: json['hex'] ?? '#000000',
      paintId: json['paintId'],
      brandName: json['brandName'],
      name: json['name'],
      code: json['code'],
      psychology: json['psychology'],
      usageTips: json['usageTips'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'hex': hex,
      'paintId': paintId,
      'brandName': brandName,
      'name': name,
      'code': code,
      'psychology': psychology,
      'usageTips': usageTips,
    };
  }
}

class ColorStory {
  final String id;
  final String ownerId;
  final String userId; // Alias for ownerId to support both
  final String title;
  final String slug;
  final String status;
  final String access;
  final String narration;
  final String? heroImageUrl;
  final String audioUrl;
  final String heroPrompt;
  final String storyText; // Raw story text for fallback
  final List<String> vibeWords;
  final String room, style;
  final double progress;
  final String progressMessage;
  final Map<String, dynamic> processing;
  final List<ColorUsageItem> usageGuide;
  final String fallbackHero; // Gradient SVG data URI for instant fallback

  // Additional fields needed for explore screen
  final List<String> themes;
  final List<String> families;
  final List<String> rooms;
  final List<String> tags;
  final String description;
  final bool isFeatured;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ColorStoryPalette> palette;
  final List<String> facets;
  final int likeCount;
  final int playCount;
  final bool spotlight;

  ColorStory.fromSnap(this.id, Map<String, dynamic> d)
      : ownerId = d['ownerId'] ?? d['userId'] ?? '',
        userId = d['userId'] ?? d['ownerId'] ?? '',
        title = d['title'] ?? d['paletteName'] ?? '',
        slug = d['slug'] ?? '',
        status = d['status'] ?? 'processing',
        access = d['access'] ?? 'private',
        narration =
            d['narration'] ?? d['storyText'] ?? '', // Support both field names
        heroImageUrl = d['heroImageUrl'],
        audioUrl = d['audioUrl'] ?? '',
        heroPrompt = d['heroPrompt'] ?? '',
        storyText =
            d['storyText'] ?? d['narration'] ?? '', // Support both field names
        vibeWords = List<String>.from(d['vibeWords'] ?? const []),
        room = d['room'] ?? d['roomType'] ?? '',
        style = d['style'] ?? d['styleTag'] ?? '',
        progress = (d['progress'] ?? 0.0).toDouble(),
        progressMessage = d['progressMessage'] ?? '',
        processing = d['processing'] as Map<String, dynamic>? ?? {},
        usageGuide = (d['usageGuide'] as List<dynamic>? ?? const [])
            .map((m) => ColorUsageItem.fromMap(Map<String, dynamic>.from(m)))
            .toList(),
        fallbackHero = d['fallbackHero'] ?? _generateFallbackFromUsageGuide(d),

        // Additional fields
        themes = List<String>.from(d['themes'] ?? const []),
        families = List<String>.from(d['families'] ?? const []),
        rooms = List<String>.from(d['rooms'] ?? const []),
        tags = List<String>.from(d['tags'] ?? const []),
        description = d['description'] ?? '',
        isFeatured = d['isFeatured'] ?? false,
        createdAt = d['createdAt'] != null
            ? (d['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt = d['updatedAt'] != null
            ? (d['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        palette = (d['palette'] as List<dynamic>? ?? const [])
            .map((item) =>
                ColorStoryPalette.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        facets = List<String>.from(d['facets'] ?? const []),
        likeCount = d['likeCount'] ?? 0,
        playCount = d['playCount'] ?? 0,
        spotlight = d['spotlight'] ?? false;

  /// Generate fallback hero from usage guide colors
  static String _generateFallbackFromUsageGuide(Map<String, dynamic> data) {
    final usageGuide = data['usageGuide'] as List<dynamic>? ?? [];
    final colors = <String>[];

    // Extract first two valid colors from usage guide
    for (final item in usageGuide) {
      if (item is Map<String, dynamic> && item['hex'] is String) {
        final hex = item['hex'] as String;
        if (hex.isNotEmpty && _isValidHex(hex)) {
          colors.add(hex);
          if (colors.length >= 2) break;
        }
      }
    }

    // Use default colors if not enough found
    if (colors.isEmpty) colors.add('#6366F1');
    if (colors.length == 1) colors.add('#8B5CF6');

    return _generateGradientDataUri(colors[0], colors[1]);
  }

  /// Validate hex color format
  static bool _isValidHex(String hex) {
    final cleanHex = hex.replaceAll('#', '');
    return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(cleanHex);
  }

  /// Generate gradient SVG data URI
  static String _generateGradientDataUri(String colorA, String colorB) {
    final hexA = colorA.startsWith('#') ? colorA : '#$colorA';
    final hexB = colorB.startsWith('#') ? colorB : '#$colorB';

    final svgContent =
        '''<svg width="1200" height="800" xmlns="http://www.w3.org/2000/svg">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="$hexA"/>
    <stop offset="100%" stop-color="$hexB"/>
  </linearGradient></defs>
  <rect width="100%" height="100%" fill="url(#g)"/>
</svg>''';

    final encoded = base64Encode(utf8.encode(svgContent));
    return 'data:image/svg+xml;base64,$encoded';
  }
}
