import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/chat.dart';
import '../services/chat_repository.dart';

/// Creator shows QR once. When they tap Done, QR is gone forever (qrDismissed).
class ShareQrScreen extends StatefulWidget {
  final Chat chat;

  const ShareQrScreen({super.key, required this.chat});

  @override
  State<ShareQrScreen> createState() => _ShareQrScreenState();
}

class _ShareQrScreenState extends State<ShareQrScreen> {
  final ChatRepository _repo = ChatRepository();
  String? _keyHex;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final hex = await _repo.getKeyHex(widget.chat.id);
    if (mounted) setState(() => _keyHex = hex);
  }

  Future<void> _onDone() async {
    await _repo.setQrDismissed(widget.chat.id);
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final keyHex = _keyHex;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Share ${widget.chat.name}',
          style: const TextStyle(color: Colors.white),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Others scan this to join. When you tap Done, this QR cannot be shown again.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (keyHex != null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: 'securechat:$keyHex|${widget.chat.name}',
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                  )
                else
                  const CircularProgressIndicator(color: Color(0xFFe94560)),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: keyHex != null ? _onDone : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFe94560),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: const Text('Done — QR will not be shown again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
