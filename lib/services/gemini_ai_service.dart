import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class GeminiAiService {
  final FirebaseFunctions _functions;

  GeminiAiService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>?> parseBillWithVision({
    Uint8List? imageBytes,
    required String instructions,
    required List<String> memberNames,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('parseBillWithAI');
      final HttpsCallableResult result = await callable.call({
        'imageBase64': imageBytes != null ? base64Encode(imageBytes) : null,
        'instructions': instructions,
        'memberNames': memberNames,
      });

      if (result.data != null) {
        return Map<String, dynamic>.from(result.data as Map);
      }
      return null;
    } catch (e) {
      debugPrint('--- GEMINI FIREBASE FUNCTION ERROR ---');
      debugPrint('Error: $e');
      debugPrint('--------------------');
      rethrow;
    }
  }

  Future<String?> queryAppState({
    required String userQuery,
    required String appContext,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('queryAppState');
      final HttpsCallableResult result = await callable.call({
        'userQuery': userQuery,
        'appContext': appContext,
      });

      if (result.data != null && result.data is Map && result.data['response'] != null) {
        return result.data['response'] as String;
      }
      return "I'm having trouble accessing your data right now. Please try again in a moment.";
    } catch (e) {
      debugPrint('Gemini Query Error: $e');
      return "I'm having trouble accessing your data right now. Please try again in a moment.";
    }
  }
}