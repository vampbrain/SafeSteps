import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_message.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  late final ChatController _chatController;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _suggestions = [
    {
      'label': '🚨 Emergency Help',
      'message': 'What should I do in case of an emergency situation?',
    },
    {
      'label': '🗺️ Safe Routes',
      'message': 'What are some tips for choosing safe walking routes?',
    },
    {
      'label': '📱 Safety Apps',
      'message': 'What are some recommended personal safety apps?',
    },
    {
      'label': '🏥 Nearby Help',
      'message': 'How can I find nearby emergency services?',
    },
    {
      'label': '🚶‍♀️ Walking Safety',
      'message': 'What are some general safety tips for walking alone?',
    },
    {
      'label': '📞 Emergency Numbers',
      'message': 'What are important emergency contact numbers I should know?',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with your Gemini API key
    _chatController = ChatController(
      apiKey: 'AIzaSyAoCbiZtu8nlJjhyVT5jIIq3OIxy2oRxAs',
    );
  }

  void _sendMessage([String? text]) {
    final messageText = text ?? _textController.text;
    if (messageText.trim().isEmpty) return;

    _chatController.sendMessage(messageText);
    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildSuggestions() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _sendMessage(suggestion['message']),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  suggestion['label']!,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: EdgeInsets.only(
          left: message.isUser ? 64 : 16,
          right: message.isUser ? 16 : 64,
          top: 8,
          bottom: 8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.black : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isUser)
              Text(
                message.text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              )
            else
              MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  strong: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                  listBullet: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  blockquote: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                shrinkWrap: true,
              ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: message.isUser ? Colors.white70 : Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Steps Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              try {
                final response = await _chatController.testApiConnection();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      response?.startsWith('Error:') ?? false
                          ? 'API Error: ${response}'
                          : 'API Test Successful! ✅',
                    ),
                    backgroundColor: response?.startsWith('Error:') ?? false
                        ? Colors.red
                        : Colors.black,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('API Test Failed: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            tooltip: 'Test API Connection',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chatController.clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSuggestions(),
          Expanded(
            child: ListenableBuilder(
              listenable: _chatController,
              builder: (context, _) {
                if (_chatController.messages.isEmpty) {
                  return const Center(child: Text('Start a conversation!'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatController.messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessage(_chatController.messages[index]);
                  },
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: _chatController,
                    builder: (context, _) {
                      return FloatingActionButton(
                        onPressed: _chatController.isLoading
                            ? null
                            : () => _sendMessage(),
                        backgroundColor: Colors.black,
                        child: _chatController.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.send),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
