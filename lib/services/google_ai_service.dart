// 🤖 GOOGLE AI SERVICE VIA FIREBASE
// Google AI integration for ColorCanvas app via Firebase Cloud Functions
// Uses Firebase Cloud Functions for secure Google AI access

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:logging/logging.dart';
import '../firestore/firestore_data_schema.dart';

class GoogleAIService {
  static final _logger = Logger('GoogleAIService');
  static final _functions = FirebaseFunctions.instance;

  // Initialize Google AI service via Firebase Cloud Functions
  static Future<void> initialize() async {
    try {
      _logger.info(
          'Google AI service initialized - using Firebase Cloud Functions');
      // Google AI logic will be handled through Firebase Cloud Functions
      // No direct model initialization needed
    } catch (e) {
      _logger.severe('Failed to initialize Google AI service: $e');
      rethrow;
    }
  }

  // Generate color story using Google AI via Firebase Cloud Functions
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
        'provider': 'google', // Specify Google AI provider
      };

      final callable = _functions.httpsCallable('generateColorStoryGoogle');
      final result = await callable.call(data);

      if (result.data != null && result.data['story'] != null) {
        _logger.info('Successfully generated color story via Google AI');
        return result.data['story'] as String;
      } else {
        throw Exception('Empty response from Firebase function');
      }
    } catch (e) {
      _logger.severe('Error generating color story via Google AI: $e');
      rethrow;
    }
  }

  // Analyze space image using Google AI via Firebase Cloud Functions
  static Future<Map<String, dynamic>> analyzeSpace(Uint8List imageBytes) async {
    try {
      // Convert image to base64 for transmission
      final base64Image = base64Encode(imageBytes);

      final data = {
        'image': base64Image,
        'mimeType': 'image/jpeg',
        'provider': 'google', // Specify Google AI provider
      };

      final callable = _functions.httpsCallable('analyzeSpaceGoogle');
      final result = await callable.call(data);

      if (result.data != null && result.data['analysis'] != null) {
        _logger.info('Successfully analyzed space image via Google AI');
        return Map<String, dynamic>.from(result.data['analysis']);
      } else {
        _logger.warning('Empty response from Firebase function, using default');
        return _getDefaultAnalysis();
      }
    } catch (e) {
      _logger.severe('Error analyzing space via Google AI: $e');
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
        'provider': 'google', // Specify Google AI provider
      };

      final callable = _functions.httpsCallable('suggestColorsGoogle');
      final result = await callable.call(data);

      if (result.data != null && result.data['suggestions'] != null) {
        _logger.info('Successfully generated color suggestions via Google AI');
        return List<String>.from(result.data['suggestions']);
      } else {
        throw Exception('Empty response from Firebase function');
      }
    } catch (e) {
      _logger.severe('Error generating color suggestions via Google AI: $e');
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

  // Test Google AI connection via Firebase Cloud Functions
  static Future<bool> testConnection() async {
    try {
      final callable = _functions.httpsCallable('testConnectionGoogle');
      final result = await callable.call({'provider': 'google'});

      final success = result.data != null && result.data['success'] == true;
      _logger
          .info('Google AI connection test: ${success ? 'PASSED' : 'FAILED'}');
      return success;
    } catch (e) {
      _logger.severe('Google AI connection test failed: $e');
      return false;
    }
  }
}
