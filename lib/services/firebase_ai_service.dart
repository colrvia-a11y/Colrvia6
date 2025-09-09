// 🤖 FIREBASE AI SERVICE
// Official Firebase AI integration for ColorCanvas app
// Uses Firebase Cloud Functions for AI logic

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:logging/logging.dart';
import '../firestore/firestore_data_schema.dart';

class FirebaseAIService {
  static final _logger = Logger('FirebaseAIService');
  static final _functions = FirebaseFunctions.instance;

  // Initialize Firebase AI models - using Firebase Cloud Functions
  static Future<void> initialize() async {
    try {
      _logger.info('Firebase AI service initialized - using Cloud Functions');
      // Firebase AI logic will be handled through Cloud Functions
      // No direct model initialization needed
    } catch (e) {
      _logger.severe('Failed to initialize Firebase AI: $e');
      rethrow;
    }
  }

  // Generate color story using Firebase Cloud Functions
  static Future<String> generateColorStory({
    required List<Paint> colors,
    required String room,
    required String style,
    required List<String> vibeWords,
    List<String> brandHints = const [],
  }) async {
    try {
      final colorDescriptions = colors.map((color) {
        return '${color.name} (${color.hex}) by ${color.brandName}';
      }).join(', ');

      final data = {
        'colors': colorDescriptions,
        'room': room,
        'style': style,
        'vibeWords': vibeWords,
        'brandHints': brandHints,
      };

      final callable = _functions.httpsCallable('generateColorStory');
      final result = await callable.call(data);

      if (result.data != null && result.data['story'] != null) {
        _logger.info('Successfully generated color story');
        return result.data['story'] as String;
      } else {
        throw Exception('Empty response from Firebase function');
      }
    } catch (e) {
      _logger.severe('Error generating color story: $e');
      rethrow;
    }
  }

  // Analyze space image using Firebase Cloud Functions
  static Future<Map<String, dynamic>> analyzeSpace(Uint8List imageBytes) async {
    try {
      // Convert image to base64 for transmission
      final base64Image = base64Encode(imageBytes);

      final data = {
        'image': base64Image,
        'mimeType': 'image/jpeg',
      };

      final callable = _functions.httpsCallable('analyzeSpace');
      final result = await callable.call(data);

      if (result.data != null && result.data['analysis'] != null) {
        _logger.info('Successfully analyzed space image');
        return Map<String, dynamic>.from(result.data['analysis']);
      } else {
        _logger.warning('Empty response from Firebase function, using default');
        return _getDefaultAnalysis();
      }
    } catch (e) {
      _logger.severe('Error analyzing space: $e');
      // Return default analysis on error
      return _getDefaultAnalysis();
    }
  }

  // Generate color suggestions based on room and style
  static Future<List<String>> suggestColors({
    required String room,
    required String style,
    required List<String> vibeWords,
  }) async {
    try {
      final data = {
        'room': room,
        'style': style,
        'vibeWords': vibeWords,
      };

      final callable = _functions.httpsCallable('suggestColors');
      final result = await callable.call(data);

      if (result.data != null && result.data['suggestions'] != null) {
        _logger.info('Successfully generated color suggestions');
        return List<String>.from(result.data['suggestions']);
      } else {
        throw Exception('Empty response from Firebase function');
      }
    } catch (e) {
      _logger.severe('Error generating color suggestions: $e');
      rethrow;
    }
  }

  // Default analysis when AI fails
  static Map<String, dynamic> _getDefaultAnalysis() {
    return {
      'space_type': 'living_room',
      'paintable_surfaces': ['walls'],
      'lighting_conditions': 'mixed',
      'style': 'modern',
      'dominant_colors': ['#FFFFFF', '#F5F5F5'],
      'surface_areas': {
        'walls': 'medium',
        'cabinets': 'none',
        'trim': 'minimal'
      },
      'perspective': 'straight_on',
      'quality_score': 0.7,
      'recommendations': 'Consider neutral tones for versatility'
    };
  }

  // Test Firebase AI connection
  static Future<bool> testConnection() async {
    try {
      final callable = _functions.httpsCallable('testConnection');
      final result = await callable.call();

      final success = result.data != null && result.data['success'] == true;
      _logger.info(
          'Firebase AI connection test: ${success ? 'PASSED' : 'FAILED'}');
      return success;
    } catch (e) {
      _logger.severe('Firebase AI connection test failed: $e');
      return false;
    }
  }

  // Generate design inspiration based on colors and preferences
  static Future<String> generateDesignInspiration({
    required List<Paint> colors,
    required String room,
    required String mood,
  }) async {
    try {
      final colorDescriptions = colors.map((color) {
        return '${color.name} (${color.hex}) by ${color.brandName}';
      }).join(', ');

      final data = {
        'colors': colorDescriptions,
        'room': room,
        'mood': mood,
      };

      final callable = _functions.httpsCallable('generateDesignInspiration');
      final result = await callable.call(data);

      if (result.data != null && result.data['inspiration'] != null) {
        _logger.info('Successfully generated design inspiration');
        return result.data['inspiration'] as String;
      } else {
        throw Exception('Empty response from Firebase function');
      }
    } catch (e) {
      _logger.severe('Error generating design inspiration: $e');
      rethrow;
    }
  }
}
