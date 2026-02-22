import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'file_utils_stub.dart'
    if (dart.library.io) 'file_utils_io.dart' as file_utils;

/// Captures images from camera. Reads bytes into RAM only.
/// Note: On mobile, camera writes to temp cache - we read bytes and delete
/// the temp file. On web, bytes come from MediaStream (no file).
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      throw CameraException('NO_CAMERA', 'No cameras available');
    }
    _controller = CameraController(
      _cameras!.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
  }

  CameraController? get controller => _controller;

  /// Captures image and returns raw bytes. Does NOT persist to user storage.
  /// Temp file is deleted immediately after reading for minimal disk exposure.
  Future<Uint8List> captureImageBytes() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw CameraException('NOT_INITIALIZED', 'Camera not initialized');
    }

    final XFile file = await _controller!.takePicture();
    Uint8List bytes;

    try {
      bytes = await file.readAsBytes();
    } finally {
      // On mobile: delete temp file after read. On web: no-op.
      await file_utils.deleteTempFileIfExists(file.path);
    }

    return bytes;
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
  }
}
