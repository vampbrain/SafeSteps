import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey;
  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  GeminiService({required this.apiKey}) {
    if (apiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }
  }

  Future<String?> generateResponse(String prompt) async {
    try {
      print('🔑 Using API Key: ${apiKey.substring(0, 8)}... (first 8 chars)');
      final url = Uri.parse('$baseUrl?key=$apiKey');

      print('📤 Sending request to Gemini API...');
      print('📝 Prompt: $prompt');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
          ],
        }),
      );

      print('📥 Response status code: ${response.statusCode}');
      print('📄 Response headers: ${response.headers}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'];
        } else {
          print('❌ Invalid response structure: $data');
          return 'Error: Invalid response structure from API';
        }
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        print('❌ API 400 Error: ${error['error']['message']}');
        if (error['error']['message'].toString().contains('API key')) {
          return 'Error: Invalid API key format. Please check your credentials.';
        }
        return 'Error: Bad request - ${error['error']['message']}';
      } else if (response.statusCode == 401) {
        print('❌ API 401 Error: Unauthorized - Invalid API key');
        return 'Error: Invalid or expired API key. Please check your credentials.';
      } else if (response.statusCode == 403) {
        print(
          '❌ API 403 Error: Forbidden - API key may not have proper permissions',
        );
        return 'Error: API key does not have proper permissions.';
      } else if (response.statusCode == 404) {
        print('❌ API 404 Error: Model or endpoint not found');
        return 'Error: The AI model is not available. Please try again later.';
      } else if (response.statusCode == 429) {
        print('❌ API 429 Error: Too Many Requests - Rate limit exceeded');
        return 'Error: Rate limit exceeded. Please try again later.';
      } else {
        print('❌ Unexpected status code: ${response.statusCode}');
        return 'Error: Unexpected error occurred. Status: ${response.statusCode}';
      }
    } catch (e, stackTrace) {
      print('❌ Error generating response: $e');
      print('📚 Stack trace: $stackTrace');
      if (e.toString().contains('SocketException')) {
        return 'Error: Network connection issue. Please check your internet connection.';
      }
      return 'Error: ${e.toString()}';
    }
  }
}
