import 'package:flutter/material.dart';

import '../config/relay_config.dart';
import '../services/chat_repository.dart';

/// Set the relay server URL so messages sync on iOS/Android (e.g. your ngrok URL).
class RelaySettingsScreen extends StatefulWidget {
  const RelaySettingsScreen({super.key});

  @override
  State<RelaySettingsScreen> createState() => _RelaySettingsScreenState();
}

class _RelaySettingsScreenState extends State<RelaySettingsScreen> {
  final ChatRepository _repo = ChatRepository();
  final _controller = TextEditingController();
  String? _currentUrl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await _repo.getRelayBaseUrl();
    final effective = url ?? kDefaultRelayBaseUrl;
    if (mounted) {
      setState(() {
        _currentUrl = url;
        _loading = false;
        _controller.text = effective;
      });
    }
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    setState(() => _saving = true);
    await _repo.setRelayBaseUrl(url.isEmpty ? null : url);
    if (mounted) {
      setState(() {
        _saving = false;
        _currentUrl = url.isEmpty ? null : url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(url.isEmpty ? 'Relay URL cleared' : 'Relay URL saved'),
          backgroundColor: const Color(0xFFe94560),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Relay server', style: TextStyle(color: Colors.white)),
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
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFe94560)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'To sync messages between two iPhones (or iPhone and web), run the Node relay server and enter its URL here on each device.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Example: On your Mac, run ./serve_ngrok.sh, then enter the https://xxx.ngrok-free.app URL shown.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                            ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          labelText: 'Relay server URL',
                          hintText: 'https://xxx.ngrok-free.app',
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
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        onSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentUrl != null && _currentUrl!.isNotEmpty
                            ? 'Saved override: $_currentUrl'
                            : 'Using default relay URL (edit lib/config/relay_config.dart for production).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFe94560),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
