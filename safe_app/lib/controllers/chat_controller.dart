import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/gemini_service.dart';

class ChatController extends ChangeNotifier {
  final GeminiService _geminiService;
  final List<ChatMessage> messages = [];
  bool isLoading = false;

  ChatController({required String apiKey})
    : _geminiService = GeminiService(apiKey: apiKey) {
    // Add welcome message
    messages.add(
      ChatMessage(
        text:
            "Hello! I'm your SafeSteps assistant. I can help you with safety-related questions, route recommendations, and emergency information. How can I assist you today?",
        isUser: false,
      ),
    );
  }

  Future<String?> testApiConnection() async {
    return _geminiService.generateResponse(
      'Hello, this is a test message. Please respond with "API is working correctly."',
    );
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    messages.add(ChatMessage(text: text, isUser: true));
    notifyListeners();

    // Show loading state
    isLoading = true;
    notifyListeners();

    try {
      // Get AI response
      final response = await _geminiService.generateResponse(text);

      if (response != null) {
        if (response.startsWith('Error:')) {
          // Handle error response
          messages.add(
            ChatMessage(
              text:
                  "I apologize, but I'm having trouble connecting to my services. Please check your internet connection and try again. If the problem persists, please contact support.",
              isUser: false,
            ),
          );
          print('Gemini API Error: $response'); // For debugging
        } else {
          // Handle successful response
          messages.add(ChatMessage(text: response, isUser: false));
        }
      } else {
        messages.add(
          ChatMessage(
            text:
                "I'm sorry, but I couldn't process your request. Please try rephrasing your question.",
            isUser: false,
          ),
        );
      }
    } catch (e) {
      print('Error in sendMessage: $e');
      messages.add(
        ChatMessage(
          text:
              "I apologize, but there seems to be a technical issue. Please try again later.",
          isUser: false,
        ),
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    messages.clear();
    // Add welcome message back
    messages.add(
      ChatMessage(
        text:
            "Hello! I'm your SafeSteps assistant. I can help you with safety-related questions, route recommendations, and emergency information. How can I assist you today?",
        isUser: false,
      ),
    );
    notifyListeners();
  }
}
