import 'package:flutter/material.dart';
import '../services/chat_repository.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class EnterAliasScreen extends StatefulWidget {
  final String keyHex;
  final String chatName;

  const EnterAliasScreen({
    super.key,
    required this.keyHex,
    required this.chatName,
  });

  @override
  State<EnterAliasScreen> createState() => _EnterAliasScreenState();
}

class _EnterAliasScreenState extends State<EnterAliasScreen> {
  final ChatRepository _repo = ChatRepository();
  final ChatService _chatService = ChatService();
  final _aliasController = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final alias = _aliasController.text.trim();
    if (alias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your alias')),
      );
      return;
    }
    setState(() => _joining = true);
    try {
      final chat = await _repo.addChatFromScan(
        keyHex: widget.keyHex,
        chatName: widget.chatName,
        myAlias: alias,
      );
      await _chatService.joinRoom(chat.id, alias);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chat.id),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _joining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Join "${widget.chatName}"',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how others will see you in this chat.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _aliasController,
                  decoration: InputDecoration(
                    labelText: 'Your alias',
                    hintText: 'e.g. Mom',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _join(),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _joining ? null : _join,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFe94560),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _joining
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Join chat'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
