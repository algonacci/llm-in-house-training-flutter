// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'chat_response.dart';

enum ChatMode { regular, streaming }

class Message {
  final String text;
  final bool isUser;
  final bool isComplete;

  Message({
    required this.text,
    required this.isUser,
    this.isComplete = true,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = []; // Fixed: Make sure this is List<Message>
  final ScrollController _scrollController = ScrollController();

  ChatMode _currentMode = ChatMode.streaming;
  String _selectedModel = 'llama3.2';
  List<String> _availableModels = ['llama3.2'];
  bool _isLoading = false;
  bool _isApiHealthy = false;

  @override
  void initState() {
    super.initState();
    _loadModels();
    _checkApiHealth();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadModels() async {
    final models = await ChatResponse.getAvailableModels();
    setState(() {
      _availableModels = models;
      if (models.isNotEmpty) {
        _selectedModel = models.first;
      }
    });
  }

  Future<void> _checkApiHealth() async {
    final isHealthy = await ChatResponse.checkHealth();
    setState(() {
      _isApiHealthy = isHealthy;
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    _controller.clear();

    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(Message(text: text, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    if (_currentMode == ChatMode.regular) {
      _sendRegularMessage(text);
    } else {
      _sendStreamingMessage(text);
    }
  }

  Future<void> _sendRegularMessage(String text) async {
    // Add placeholder for bot response
    setState(() {
      _messages
          .add(Message(text: 'Thinking...', isUser: false, isComplete: false));
    });

    final response =
        await ChatResponse.getChatResponseRegular(text, model: _selectedModel);

    setState(() {
      _messages[_messages.length - 1] =
          Message(text: response, isUser: false, isComplete: true);
      _isLoading = false;
    });

    _scrollToBottom();
  }

  void _sendStreamingMessage(String text) {
    // Add placeholder for bot response
    setState(() {
      _messages.add(Message(text: '', isUser: false, isComplete: false));
    });

    var response = '';
    ChatResponse.getChatResponseStreaming(text, model: _selectedModel).listen(
      (chunk) {
        setState(() {
          response += chunk;
          _messages[_messages.length - 1] =
              Message(text: response, isUser: false, isComplete: false);
        });
        _scrollToBottom();
      },
      onDone: () {
        setState(() {
          _messages[_messages.length - 1] =
              Message(text: response, isUser: false, isComplete: true);
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _messages[_messages.length - 1] =
              Message(text: 'Error: $error', isUser: false, isComplete: true);
          _isLoading = false;
        });
      },
    );
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

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat ${_currentMode.name.toUpperCase()}'),
        backgroundColor: _currentMode == ChatMode.regular
            ? colorScheme.primaryContainer
            : colorScheme.secondaryContainer,
        foregroundColor: _currentMode == ChatMode.regular
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSecondaryContainer,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearChat();
              } else if (value == 'health') {
                _checkApiHealth();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(_isApiHealthy ? 'API is healthy' : 'API is down'),
                    backgroundColor:
                        _isApiHealthy ? colorScheme.primary : colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
              const PopupMenuItem(value: 'health', child: Text('Check API')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControls(),
          _buildMessages(),
          _buildUserInput(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          SegmentedButton<ChatMode>(
            segments: const [
              ButtonSegment(
                value: ChatMode.regular,
                label: Text('Regular'),
                icon: Icon(Icons.chat_bubble_outline),
              ),
              ButtonSegment(
                value: ChatMode.streaming,
                label: Text('Streaming'),
                icon: Icon(Icons.stream),
              ),
            ],
            selected: {_currentMode},
            onSelectionChanged: (Set<ChatMode> selection) {
              setState(() {
                _currentMode = selection.first;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Badge(
                backgroundColor:
                    _isApiHealthy ? colorScheme.primary : colorScheme.error,
                smallSize: 8,
              ),
              const SizedBox(width: 8),
              Text(
                'API: ${_isApiHealthy ? 'Connected' : 'Disconnected'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isApiHealthy
                          ? colorScheme.primary
                          : colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              Text(
                'Model: ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedModel,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedModel = newValue;
                      });
                    }
                  },
                  underline: const SizedBox(),
                  isExpanded: true,
                  items: _availableModels
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return _buildMessageBubble(message);
        },
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: message.isUser
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            if (!message.isUser && !message.isComplete) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserInput() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isLoading,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _isLoading
                      ? 'Please wait...'
                      : 'Type your message here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        BorderSide(color: colorScheme.primary, width: 2),
                  ),
                  filled: true,
                  fillColor:
                      colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _isLoading ? null : _sendMessage,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: colorScheme.onPrimary,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
