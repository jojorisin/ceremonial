import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/key_service.dart';

class QrDisplayScreen extends StatefulWidget {
  const QrDisplayScreen({super.key});

  @override
  State<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends State<QrDisplayScreen> {
  final KeyService _keyService = KeyService();
  String? _keyHex;
  String? _chatName;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    try {
      final key = await _keyService.getStoredKey();
      final name = await _keyService.getChatName();
      if (mounted) {
        setState(() {
          _keyHex = key;
          _chatName = name;
          _error = key == null ? 'No key found' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to load key: $e');
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
              children: [
                Text(
                  'Share Key via QR',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Other device scans this to receive the same key',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.redAccent))
                else if (_keyHex != null) ...[
                  if (_chatName != null && _chatName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Chat: $_chatName',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: _chatName != null && _chatName!.isNotEmpty
                          ? 'securechat:${_keyHex!}|$_chatName'
                          : 'securechat:${_keyHex!}',
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ]
                else
                  const CircularProgressIndicator(color: Color(0xFFe94560)),
                const Spacer(),
                if (_keyHex != null)
                  Text(
                    'Both devices must be in the same room',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
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
