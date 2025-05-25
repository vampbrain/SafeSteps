import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  final String apiKey;
  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

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
