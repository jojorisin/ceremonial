import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'enter_alias_screen.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _scanned = false;
  /// Lazy-loaded controller: created only when this screen is opened, disposed when left.
  /// autoStart: false defers native/ML init until after first frame to reduce memory pressure.
  late final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    returnImage: false, // avoid keeping image buffers in memory
    detectionSpeed: DetectionSpeed.normal,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scanned) return;
      _controller.start();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue ?? barcode?.displayValue ?? '';
    if (raw.isEmpty) return;
    String keyHex;
    String chatName = '';
    if (raw.startsWith('securechat:')) {
      final rest = raw.substring('securechat:'.length).trim();
      final pipe = rest.indexOf('|');
      if (pipe >= 0) {
        keyHex = rest.substring(0, pipe).trim();
        if (pipe + 1 < rest.length) {
          chatName = rest.substring(pipe + 1).trim();
        }
      } else {
        keyHex = rest;
      }
    } else {
      keyHex = raw.trim();
    }
    if (keyHex.length != 64) return;
    _scanned = true;
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EnterAliasScreen(
            keyHex: keyHex,
            chatName: chatName.isEmpty ? 'Unnamed chat' : chatName,
          ),
        ),
      );
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
                      child: Text(
                        'Scan QR to Receive Key',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Point camera at the other device\'s QR code',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
