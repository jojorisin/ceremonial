import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hashlib/codecs.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/camera_service.dart';
import '../services/key_service.dart';
import 'name_alias_screen.dart';

class KeyGenerationScreen extends StatefulWidget {
  const KeyGenerationScreen({super.key});

  @override
  State<KeyGenerationScreen> createState() => _KeyGenerationScreenState();
}

class _KeyGenerationScreenState extends State<KeyGenerationScreen> {
  final CameraService _cameraService = CameraService();
  final KeyService _keyService = KeyService();

  bool _initialized = false;
  bool _processing = false;
  String? _error;
  String? _successMessage;
  bool _permanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    // Defer permission request until after first frame so iOS shows the dialog reliably.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  Future<void> _initializeCamera() async {
    try {
      // Request on iOS works best after the view is visible; check status first.
      PermissionStatus status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      if (!status.isGranted) {
        if (mounted) {
          final isPermanentlyDenied = status.isPermanentlyDenied;
          setState(() {
            _permanentlyDenied = isPermanentlyDenied;
            _error = isPermanentlyDenied
                ? 'Camera access was denied. Open Settings to allow camera.'
                : 'Camera permission required to generate key';
          });
        }
        return;
      }
      _permanentlyDenied = false;
      await _cameraService.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
          _error = null;
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _error = 'Camera error: $e');
      }
      debugPrint('Camera init error: $e\n$st');
    }
  }


  Future<void> _captureAndDeriveKey() async {
    if (_processing || !_initialized) return;

    setState(() {
      _processing = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final imageBytes = await _cameraService.captureImageBytes();
      final salt = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      final keyHex = _keyService.deriveKeyFromImageWithSalt(imageBytes, salt);
      final saltHex = toHex(salt);

      if (mounted) {
        setState(() {
          _processing = false;
          _successMessage = 'Key derived. Enter chat name and your alias.';
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => NameAliasScreen(keyHex: keyHex, saltHex: saltHex),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = 'Key generation failed: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
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
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                'Secure Chat',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Key Generation',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: _buildContent(),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: _buildCaptureButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              if (_permanentlyDenied) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFe94560)),
            SizedBox(height: 16),
            Text('Initializing camera...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 320,
                child: CameraPreview(_cameraService.controller!),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Capture a shared visual (e.g. poster, object) visible to both devices in the same room. The image is hashed with SHA-3, derived into a key, and stored in Secure Enclave / TEE. Nothing is saved to disk.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFe94560).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFe94560).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFFe94560)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return FilledButton(
      onPressed: _processing ? null : _captureAndDeriveKey,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFe94560),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 56),
      ),
      child: _processing
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt),
                SizedBox(width: 12),
                Text('Capture & Generate Key'),
              ],
            ),
    );
  }
}
