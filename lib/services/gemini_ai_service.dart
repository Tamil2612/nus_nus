import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiAiService {
  static const String _apiKey = 'YOUR API KEY HERE';

  final GenerativeModel _model;

  GeminiAiService()
      : _model = GenerativeModel(
          model: 'gemini-3.6-flash',
          apiKey: _apiKey,
          systemInstruction: Content.system(
              'You are a highly accurate financial calculation engine for the Nus·Nus app. '
              'Your mission is to parse provided receipt images and apply specific split instructions. '
              'Strictly follow user instructions over default logic. '
              'Distribute taxes/fees proportionally. '
              'Only use names from the provided member list. '
              'ALWAYS return ONLY valid raw JSON.'),
        );

  Future<Map<String, dynamic>?> parseBillWithVision({
    Uint8List? imageBytes,
    required String instructions,
    required List<String> memberNames,
  }) async {
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;

    final prompt = '''
---
USER INSTRUCTIONS: $instructions
MEMBER LIST: ${memberNames.join(', ')}
---

${!hasImage ? 'IMPORTANT: No image was provided. Rely ENTIRELY on the instructions above.' : 'Parse the image and follow the instructions.'}

STRICT CALCULATION RULES:
1. OVERRIDE DEFAULT LOGIC: Use specific percentages or amounts if provided.
2. SUM INTEGRITY: Sum of splitMap MUST equal amount.

EXAMPLE 1 (Exclusion):
Instructions: "Total 100. Person A paid. Split between all except Person B."
Result: {"description": "...", "amount": 100, "payerName": "Person A", "splitMap": {"Person A": 50, "Person C": 50}}

JSON Schema:
{
  "description": "string",
  "amount": number,
  "payerName": "string",
  "splitMap": { "MemberName": number }
}
''';

    final List<Content> content = [
      if (hasImage)
        Content.multi([
          DataPart('image/jpeg', imageBytes),
          TextPart(prompt),
        ])
      else
        Content.text(prompt)
    ];

    try {
      final response = await _model.generateContent(content);
      final text = response.text;
      if (text == null) return null;

      // Clean up potential markdown formatting from AI response
      String cleanJson = text.trim();
      if (cleanJson.contains('```')) {
        final lines = cleanJson.split('\n');
        final buffer = StringBuffer();
        bool inJson = false;
        for (final line in lines) {
          if (line.startsWith('```')) {
            inJson = !inJson;
            continue;
          }
          if (inJson || !line.contains('```')) {
            buffer.writeln(line);
          }
        }
        cleanJson = buffer.toString().trim();
      }

      if (cleanJson.isEmpty) {
        cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      }

      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('--- GEMINI ERROR ---');
      debugPrint('Error: $e');
      debugPrint('Check if your API Key is valid and has access to the model.');
      debugPrint('--------------------');

      if (e.toString().toLowerCase().contains('quota')) {
        rethrow;
      }
      return null;
    }
  }

  Future<String?> queryAppState({
    required String userQuery,
    required String appContext,
  }) async {
    final prompt = '''
You are "Nus AI", a professional financial analyst.

USER'S DATA CONTEXT (JSON):
$appContext

USER'S QUESTION:
$userQuery

STRICT GUIDELINES:
1. Accuracy: Only use provided data.
2. Conciseness: Be brief. Use bullet points.
3. Currency: Always specify currency.
4. Persona: Friendly and helpful.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text;
    } catch (e) {
      debugPrint('Gemini Query Error: $e');
      return "I'm having trouble accessing your data right now. Please try again in a moment.";
    }
  }
}
