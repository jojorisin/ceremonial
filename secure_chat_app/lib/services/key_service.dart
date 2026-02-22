import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hashlib/codecs.dart';
import 'package:hashlib/hashlib.dart' as hashlib;

/// Handles secure key generation from camera image and storage in
/// Secure Enclave (iOS) / TEE-backed storage (Android).
///
/// Flow: image bytes → SHA-3-256 → PBKDF2 derivation → secure storage
class KeyService {
  static const _keyStorageKey = 'secure_chat_derived_key';
  static const _chatNameKey = 'secure_chat_name';
  static const _salt = 'secure_chat_key_salt_v1'; // Fixed salt for deterministic derivation
  static const _pbkdf2Iterations = 100000;

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Derives an encryption key from raw image bytes (no storage).
  /// Uses fixed salt for backward compatibility when no salt is provided.
  String deriveKeyFromImage(List<int> imageBytes) {
    return deriveKeyFromImageWithSalt(imageBytes, _salt.codeUnits);
  }

  /// Derives key with a cryptographically random salt (unique per chat).
  /// Salt should be 32 bytes from Random.secure().
  String deriveKeyFromImageWithSalt(List<int> imageBytes, List<int> salt) {
    final hashDigest = hashlib.sha3_256.convert(imageBytes);
    final hashBytes = hashDigest.bytes;
    final digest = hashlib.pbkdf2(
      hashBytes,
      salt,
      _pbkdf2Iterations,
      32,
    );
    return toHex(digest.bytes);
  }

  /// Legacy: derive and store single key (for backward compat).
  Future<String> deriveAndStoreKey(List<int> imageBytes) async {
    final keyHex = deriveKeyFromImage(imageBytes);
    await _storage.write(key: _keyStorageKey, value: keyHex);
    return keyHex;
  }

  /// Reads the stored key from secure storage.
  Future<String?> getStoredKey() async {
    return _storage.read(key: _keyStorageKey);
  }

  /// Clears the stored key (e.g. on logout).
  Future<void> clearKey() async {
    await _storage.delete(key: _keyStorageKey);
  }

  /// Store key from scanned QR code. Key must be 64-char hex (256-bit).
  Future<void> storeKeyFromHex(String keyHex) async {
    final trimmed = keyHex.trim();
    if (trimmed.length != 64 || !RegExp(r'^[a-fA-F0-9]+$').hasMatch(trimmed)) {
      throw ArgumentError('Invalid key format: expected 64 hex chars');
    }
    await _storage.write(key: _keyStorageKey, value: trimmed);
  }

  /// Chat name for this key (shown in UI, shared via QR).
  Future<String?> getChatName() async => _storage.read(key: _chatNameKey);

  Future<void> setChatName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _storage.write(key: _chatNameKey, value: trimmed);
  }

  /// Store key and chat name from scanned QR (format: securechat:KEY|NAME).
  Future<void> storeKeyAndChatName(String keyHex, String chatName) async {
    await storeKeyFromHex(keyHex);
    final trimmed = chatName.trim();
    if (trimmed.isNotEmpty) {
      await _storage.write(key: _chatNameKey, value: trimmed);
    }
  }

  /// Returns raw key bytes (32) for encryption. Null if no key.
  Future<Uint8List?> getKeyBytes() async {
    final hex = await getStoredKey();
    if (hex == null || hex.length != 64) return null;
    return Uint8List.fromList(fromHex(hex));
  }

  /// Room ID for message sync (opaque hash; server never sees key).
  Future<String?> getRoomId() async {
    final key = await getKeyBytes();
    if (key == null) return null;
    final digest = hashlib.sha256.convert(key);
    return toHex(digest.bytes);
  }

  /// Check if a key has been generated and stored.
  Future<bool> hasKey() async {
    final key = await getStoredKey();
    return key != null && key.isNotEmpty;
  }
}
