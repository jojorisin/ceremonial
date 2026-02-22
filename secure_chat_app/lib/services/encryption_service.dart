import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM encryption for chat messages.
class EncryptionService {
  static final _algo = AesGcm.with256bits();

  /// Encrypt plaintext with the given 256-bit key.
  static Future<String> encrypt(String plaintext, Uint8List key) async {
    if (key.length != 32) throw ArgumentError('Key must be 32 bytes');
    final secretKey = SecretKey(key);
    final secretBox = await _algo.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
    );
    return base64Encode(secretBox.concatenation());
  }

  /// Decrypt ciphertext (base64) with the given 256-bit key.
  static Future<String> decrypt(String encryptedBase64, Uint8List key) async {
    if (key.length != 32) throw ArgumentError('Key must be 32 bytes');
    final bytes = base64Decode(encryptedBase64);
    final secretBox = SecretBox.fromConcatenation(
      bytes,
      nonceLength: _algo.nonceLength,
      macLength: _algo.macAlgorithm.macLength,
    );
    final secretKey = SecretKey(key);
    final decrypted = await _algo.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(decrypted);
  }
}
