import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiAiService {
  static const String _apiKey = 'YOUR API KEY HERE';

  final GenerativeModel _model;

  GeminiAiService()
      : _model = GenerativeModel(
          model: 'gemini-3.6-flash',
          apiKey: _apiKey,
          requestOptions: const RequestOptions(apiVersion: 'v1beta'),
        );

  Future<Map<String, dynamic>?> parseBillWithVision({
    required Uint8List imageBytes,
    required String instructions,
    required List<String> memberNames,
  }) async {
    final prompt = '''
You are a highly accurate financial calculation engine for the Nus·Nus app.
Your mission is to parse the provided receipt image and apply the user's specific split instructions.

---
USER INSTRUCTIONS: $instructions
MEMBER LIST: ${memberNames.join(', ')}
---

STRICT CALCULATION RULES:
1. OVERRIDE DEFAULT LOGIC: If the user provides specific instructions (e.g., "X owes 70%"), you MUST follow them exactly. Only use equal splitting if the instructions are vague or absent.
2. IDENTIFY PAYER: Determine who paid based on the instructions. If not mentioned, use the first person in the member list.
3. HANDLING PERCENTAGES: If instructions say "X owes 30%", calculate 0.3 * Total Amount for X.
4. PROPORTIONAL TAX/FEES: If there are taxes, service charges, or tips on the bill, distribute them proportionally among everyone participating in the split.
5. SUM INTEGRITY: The sum of all values in the 'splitMap' MUST exactly equal the 'amount' field.
6. MEMBER MAPPING: Only use names provided in the MEMBER LIST.

EXAMPLE 1 (Exclusion):
Instructions: "Total 100. Vivek paid. Split between all except Pushpa."
Result: {"description": "...", "amount": 100, "payerName": "Vivek", "splitMap": {"Vivek": 50, "Vivek2": 50}}

EXAMPLE 2 (Percentage):
Instructions: "Total 200. I paid. Pushpa owes 25%."
Result: {"description": "...", "amount": 200, "payerName": "You", "splitMap": {"You": 150, "Pushpa": 50}}

EXAMPLE 3 (Specific Items):
Instructions: "The pizza was 60, split it between Vivek and Pushpa. I had the 20 drink."
Result: {"description": "...", "amount": 80, "payerName": "...", "splitMap": {"Vivek": 30, "Pushpa": 30, "You": 20}}

RESPONSE FORMAT:
ONLY return a valid JSON object. No conversation, no markdown code blocks.

JSON Schema:
{
  "description": "string",
  "amount": number,
  "payerName": "string",
  "splitMap": {
    "MemberName": number
  }
}
''';

    final content = [
      Content.multi([
        DataPart('image/jpeg', imageBytes),
        TextPart(prompt),
      ])
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
      
      // Fallback for very simple cases if the above fails
      if (cleanJson.isEmpty) {
        cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      }

      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      print('--- GEMINI ERROR ---');
      print('Error: $e');
      print('Check if your API Key is valid and has access to gemini-1.5-flash.');
      print('Standard keys from AI Studio start with "AIza".');
      print('--------------------');
      
      // Propagate quota errors specifically so the UI can handle them
      if (e.toString().toLowerCase().contains('quota')) {
        rethrow;
      }
      return null;
    }
  }
}
