import 'package:cloud_functions/cloud_functions.dart';
import 'package:logging/logging.dart';
// ...existing code...
import '../firestore/firestore_data_schema.dart';

class AiService {
  static final _logger = Logger('AiService');
  static final _f = FirebaseFunctions.instance;

  static Future<String> generateColorStory({
    required UserPalette palette,
    required String room,
    required String style,
    required List<String> vibeWords,
    List<String> brandHints = const [],
  }) async {
    // 🐛 DEBUG: Validate inputs before sending
    if (palette.colors.isEmpty) {
      throw Exception('Cannot generate color story: Palette has no colors');
    }

    final safeName =
        palette.name.trim().isEmpty ? 'Untitled Palette' : palette.name;
    final safeRoom = room.trim().isEmpty ? 'living room' : room;
    final safeStyle = style.trim().isEmpty ? 'modern' : style;

    final parameters = <String, dynamic>{
      'palette': {
        'id': palette.id,
        'name': safeName,
        'items': palette.colors
            .map((c) => {
                  'hex': c.hex, // Fallback for null hex (removed ?? operator)
                  'brandName':
                      (c.brand?.trim().isEmpty == true) ? '' : (c.brand ?? ''),
                  'name': c.name.trim().isEmpty ? 'Untitled Color' : c.name,
                  'code': c.code.trim().isEmpty ? '' : c.code,
                })
            .toList(),
      },
      'room': safeRoom,
      'style': safeStyle,
      'vibeWords':
          List<String>.from(vibeWords.where((v) => v.trim().isNotEmpty)),
      'brandHints':
          List<String>.from(brandHints.where((b) => b.trim().isNotEmpty)),
    };

    try {
      _logger.info('Calling generateColorPlan with parameters: $parameters');

      final res =
          await _f.httpsCallable('generateColorPlanV1').call(parameters);
      _logger.info('Cloud Function response type: ${res.runtimeType}');
      _logger.info('Cloud Function raw response: $res');

      final data = res.data as Map<String, dynamic>;
      _logger.info('Response data: $data');
      _logger.info('Data keys: ${data.keys.toList()}');

      if (data['error'] == true) {
        final errorMessage = data['message'] ?? 'Unknown server error';
        _logger.warning('Server returned error: $errorMessage');
        throw Exception('Server error: $errorMessage');
      }

      // Extract plan ID from standardized Cloud Function response
      // Note: Server returns 'docId' field, not 'storyId'
      String? storyId = data['docId'] as String?;

      _logger
          .info('Extracted storyId: "$storyId" (type: ${storyId.runtimeType})');
      _logger.info('Available keys in response: ${data.keys.toList()}');

      if (storyId == null || storyId.isEmpty) {
        _logger.warning('Invalid plan id - null or empty');
        throw Exception(
            'Server did not return a valid story ID. Response: $data');
      }

      _logger.info('SUCCESS - returning storyId: $storyId');
      return storyId;
    } catch (e) {
      _logger.severe('generateColorStory error: $e');
      _logger.severe('generateColorStory error type: ${e.runtimeType}');
      if (e is Exception) {
        _logger.severe('generateColorStory exception details: ${e.toString()}');
      }

      // Handle Firebase Functions specific errors
      if (e.toString().contains('unauthenticated') ||
          e.toString().contains('Authentication')) {
        throw Exception('Please sign in to generate color stories');
      }

      rethrow;
    }
  }

  static Future<String> generateVariant(String storyId,
      {String emphasis = '', List<String> vibeTweaks = const []}) async {
    // Create JSON-safe parameters for Cloud Function
    final Map<String, dynamic> parameters = {
      'storyId': storyId,
      'emphasis': emphasis,
      'vibeTweaks': List<String>.from(vibeTweaks),
    };

    final res =
        await _f.httpsCallable('generateColorStoryVariant').call(parameters);
    final data = res.data as Map<String, dynamic>;

    // Check for success response
    if (data['success'] != true || data['storyId'] == null) {
      throw Exception('Failed to generate color story variant');
    }

    return data['storyId'] as String;
  }

  /// Retry a specific generation step for a color story
  static Future<void> retryStoryStep({
    required String storyId,
    required String step, // 'writing', 'usage', 'hero', 'audio'
  }) async {
    final parameters = <String, dynamic>{
      'storyId': storyId,
      'step': step,
    };

    try {
      _logger.info('Retrying step $step for story $storyId');

      final res = await _f.httpsCallable('retryStoryStep').call(parameters);
      final data = res.data as Map<String, dynamic>;

      if (data['success'] != true) {
        final errorMessage = data['message'] ?? 'Unknown error occurred';
        final errorCode = data['code'] ?? 'retry_failed';

        _logger.warning(
            'Retry failed with code: $errorCode, message: $errorMessage');

        // Create a more specific exception with error details
        throw StepRetryException(
          step: step,
          code: errorCode,
          message: errorMessage,
        );
      }

      _logger.info('Successfully initiated retry for step $step');
    } catch (e) {
      _logger.severe('retryStoryStep error: $e');

      // If it's already our custom exception, rethrow as-is
      if (e is StepRetryException) {
        rethrow;
      }

      // Wrap other exceptions in our custom type
      throw StepRetryException(
        step: step,
        code: 'network_error',
        message: e.toString(),
      );
    }
  }
}

/// Custom exception for step retry failures
class StepRetryException implements Exception {
  final String step;
  final String code;
  final String message;

  const StepRetryException({
    required this.step,
    required this.code,
    required this.message,
  });

  @override
  String toString() =>
      'StepRetryException(step: $step, code: $code, message: $message)';
}
