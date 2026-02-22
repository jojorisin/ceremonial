import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_observer.dart';
import '../models/chat.dart';
import '../services/chat_repository.dart';
import '../services/chat_service.dart';
import 'key_generation_screen.dart';
import 'qr_scan_screen.dart';
import 'share_qr_screen.dart';
import 'chat_screen.dart';
import 'relay_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final ChatRepository _repo = ChatRepository();
  List<Chat> _chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadChats();
  }

  Future<void> _loadChats() async {
    final chats = await _repo.getAllChats();
    if (mounted) {
      setState(() {
        _chats = chats;
        _loading = false;
      });
    }
  }

  Future<void> _panicWipe() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Panic — delete everything?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete ALL keys, chat history, and messages from this device and from the server. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final roomIds = await _repo.deleteAll();
      await ChatService().wipeRooms(roomIds);
      if (mounted) _loadChats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Secure Chat',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'E2E encrypted • No keys on servers',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _ActionChip(
                        icon: Icons.camera_alt,
                        label: 'Create Chat',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KeyGenerationScreen(),
                          ),
                        ).then((_) => _loadChats()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionChip(
                        icon: Icons.qr_code_scanner,
                        label: 'Scan QR',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const QrScanScreen(),
                          ),
                        ).then((_) => _loadChats()),
                      ),
                    ),
                  ],
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 12),
                  _ActionChip(
                    icon: Icons.cloud_outlined,
                    label: 'Relay server (for sync)',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RelaySettingsScreen(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_loading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFFe94560)),
                    ),
                  )
                else if (_chats.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No chats yet.\nCreate a chat or scan a QR to join.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white54,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: [
                        ...List.generate(_chats.length, (i) {
                          final chat = _chats[i];
                          return _ChatCard(
                            chat: chat,
                            onOpenChat: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(chatId: chat.id),
                              ),
                            ).then((_) => _loadChats()),
                            onShareQr: chat.isCreator && !chat.qrDismissed
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ShareQrScreen(chat: chat),
                                      ),
                                    ).then((_) => _loadChats())
                                : null,
                          );
                        }),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _chats.isEmpty ? null : _panicWipe,
                          icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                          label: const Text(
                            'Panic — delete all keys & chats',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white12,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFe94560), size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final Chat chat;
  final VoidCallback onOpenChat;
  final VoidCallback? onShareQr;

  const _ChatCard({
    required this.chat,
    required this.onOpenChat,
    this.onShareQr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chat.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You as ${chat.myAlias}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onOpenChat,
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('Open Chat'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFe94560),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              if (onShareQr != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onShareQr,
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('Share QR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white38),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
