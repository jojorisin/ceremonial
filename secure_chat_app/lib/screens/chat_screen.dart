import 'dart:async';

import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/chat_repository.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatRepository _repo = ChatRepository();
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  Chat? _chat;
  List<Map<String, dynamic>> _messages = [];
  List<String> _participants = [];
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _loadMessages();
        _loadParticipants();
      }
    });
  }

  Future<void> _init() async {
    final chat = await _repo.getChat(widget.chatId);
    if (chat != null && mounted) {
      await _chatService.joinRoom(widget.chatId, chat.myAlias);
      setState(() => _chat = chat);
    }
    await _loadMessages();
    await _loadParticipants();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMessages() async {
    final msgs = await _chatService.getMessages(widget.chatId);
    if (mounted) {
      setState(() => _messages = msgs);
    }
  }

  Future<void> _loadParticipants() async {
    final list = await _chatService.getParticipants(widget.chatId);
    if (mounted) {
      setState(() => _participants = list);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _chat == null) return;
    _controller.clear();
    try {
      await _chatService.addMessage(
        chatId: widget.chatId,
        text: text,
        isMe: true,
        senderAlias: _chat!.myAlias,
        expiresIn: _chat!.autoDeleteAfter,
      );
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    }
  }

  Future<void> _setAutoDelete() async {
    if (_chat == null) return;
    final chosen = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Auto-delete messages', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Messages will be removed from the server after this time.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Never'),
          ),
          TextButton(onPressed: () => Navigator.pop(context, 3600), child: const Text('1 hour')),
          TextButton(onPressed: () => Navigator.pop(context, 86400), child: const Text('24 hours')),
          TextButton(onPressed: () => Navigator.pop(context, 604800), child: const Text('7 days')),
        ],
      ),
    );
    if (chosen != null && mounted) {
      await _repo.setAutoDeleteAfter(widget.chatId, chosen);
      final chat = await _repo.getChat(widget.chatId);
      if (mounted && chat != null) setState(() => _chat = chat);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0f0f23),
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _chat?.name ?? 'Secure Chat',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (_participants.isNotEmpty)
                            Text(
                              _participants.join(', '),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () {
                        _loadMessages();
                        _loadParticipants();
                      },
                      tooltip: 'Refresh',
                    ),
                    IconButton(
                      icon: const Icon(Icons.timer_outlined, color: Colors.white70),
                      onPressed: _setAutoDelete,
                      tooltip: 'Auto-delete',
                    ),
                    IconButton(
                      icon: const Icon(Icons.lock, color: Color(0xFFe94560)),
                      onPressed: () {},
                      tooltip: 'End-to-end encrypted',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFe94560)),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'No messages yet.\nSend one below.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: Colors.white54),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _messages.length,
                            itemBuilder: (context, i) {
                              final m = _messages[i];
                              final isMe = m['isMe'] as bool? ?? true;
                              final verified = m['verified'] as bool? ?? false;
                              final senderAlias = m['senderAlias'] as String? ?? '';
                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? const Color(0xFFe94560)
                                        : Colors.white12,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isMe && senderAlias.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                senderAlias,
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.8),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (verified) ...[
                                                const SizedBox(width: 4),
                                                const Icon(Icons.verified, color: Colors.greenAccent, size: 14),
                                              ],
                                            ],
                                          ),
                                        ),
                                      Text(
                                        m['text'] as String? ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black26,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white12,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFe94560),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
