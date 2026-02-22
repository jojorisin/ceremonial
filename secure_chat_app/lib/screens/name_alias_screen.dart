import 'package:flutter/material.dart';
import '../services/chat_repository.dart';
import 'share_qr_screen.dart';

class NameAliasScreen extends StatefulWidget {
  final String keyHex;
  final String? saltHex;

  const NameAliasScreen({super.key, required this.keyHex, this.saltHex});

  @override
  State<NameAliasScreen> createState() => _NameAliasScreenState();
}

class _NameAliasScreenState extends State<NameAliasScreen> {
  final ChatRepository _repo = ChatRepository();
  final _nameController = TextEditingController();
  final _aliasController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _createChat() async {
    final name = _nameController.text.trim();
    final alias = _aliasController.text.trim();
    if (name.isEmpty || alias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter chat name and your alias')),
      );
      return;
    }
    if (name.contains('|')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat name cannot contain |')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final chat = await _repo.createChat(
        keyHex: widget.keyHex,
        saltHex: widget.saltHex,
        name: name,
        myAlias: alias,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ShareQrScreen(chat: chat),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
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
                  'Name this chat',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Others will see this name when they scan your QR.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration('Chat name', 'e.g. Family'),
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your alias',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _aliasController,
                  decoration: _inputDecoration('Your alias', 'e.g. Mom'),
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _createChat(),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _creating ? null : _createChat,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFe94560),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _creating
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create & show QR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white12,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
