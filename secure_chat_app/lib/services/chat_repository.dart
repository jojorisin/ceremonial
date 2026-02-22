import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hashlib/codecs.dart';
import 'package:hashlib/hashlib.dart' as hashlib;
import 'package:uuid/uuid.dart';

import '../models/chat.dart';
import 'ratchet.dart';

/// Manages multiple chats. Keys, salts, ratchet state, and signing keys in secure storage.
class ChatRepository {
  static const _metadataKey = 'secure_chat_metadata';
  static const _keyPrefix = 'secure_chat_key_';
  static const _saltPrefix = 'secure_chat_salt_';
  static const _ratchetIndexPrefix = 'secure_chat_ratchet_idx_';
  static const _chainKeyPrefix = 'secure_chat_chain_';
  static const _signKeyPrefix = 'secure_chat_sign_';
  static const _sentKeyPrefix = 'secure_chat_sent_';
  static const _relayUrlKey = 'secure_chat_relay_url';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _uuid = const Uuid();
  static final _ed25519 = Ed25519();

  /// Cache message keys for skipped indices so out-of-order messages can be decrypted.
  static final Map<String, Map<int, Uint8List>> _receiveMessageKeyCache = {};
  /// Cache message key when we send so we can decrypt our own message when we fetch the list.
  static final Map<String, Map<int, Uint8List>> _sentMessageKeyCache = {};
  static const int _maxCachedKeysPerChat = 256;

  Future<List<Chat>> getAllChats() async {
    final json = await _storage.read(key: _metadataKey);
    if (json == null || json.isEmpty) return [];
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final list = data['chats'] as List?;
      if (list == null) return [];
      return list.map((e) => Chat.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Chat?> getChat(String id) async {
    final chats = await getAllChats();
    try {
      return chats.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveChats(List<Chat> chats) async {
    final list = chats.map((c) => c.toJson()).toList();
    await _storage.write(key: _metadataKey, value: jsonEncode({'chats': list}));
  }

  /// Create a new chat (creator). Key must be 64-char hex. Optional saltHex (64 hex chars) for random salt.
  Future<Chat> createChat({
    required String keyHex,
    String? saltHex,
    required String name,
    required String myAlias,
  }) async {
    _validateKeyHex(keyHex);
    final id = _uuid.v4();
    await _storage.write(key: _keyPrefix + id, value: keyHex.trim());
    if (saltHex != null && saltHex.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(saltHex)) {
      await _storage.write(key: _saltPrefix + id, value: saltHex.trim());
    }
    await _initRatchet(id);
    await _ensureSigningKey(id);
    final chat = Chat(
      id: id,
      name: name.trim(),
      myAlias: myAlias.trim(),
      qrDismissed: false,
      isCreator: true,
    );
    final chats = await getAllChats();
    chats.insert(0, chat);
    await _saveChats(chats);
    return chat;
  }

  /// Add chat from scanning QR (participant).
  Future<Chat> addChatFromScan({
    required String keyHex,
    required String chatName,
    required String myAlias,
  }) async {
    _validateKeyHex(keyHex);
    final id = _uuid.v4();
    await _storage.write(key: _keyPrefix + id, value: keyHex.trim());
    await _initRatchet(id);
    await _ensureSigningKey(id);
    final chat = Chat(
      id: id,
      name: chatName.trim(),
      myAlias: myAlias.trim(),
      qrDismissed: true,
      isCreator: false,
    );
    final chats = await getAllChats();
    chats.insert(0, chat);
    await _saveChats(chats);
    return chat;
  }

  Future<void> _initRatchet(String chatId) async {
    final key = await getKeyBytes(chatId);
    if (key == null || key.length != 32) return;
    final chainKey = Ratchet.initialChainKey(key);
    await _storage.write(key: _ratchetIndexPrefix + chatId, value: '0');
    await _storage.write(key: _chainKeyPrefix + chatId, value: toHex(chainKey));
  }

  Future<void> _ensureSigningKey(String chatId) async {
    final existing = await _storage.read(key: _signKeyPrefix + chatId);
    if (existing != null && existing.length >= 64) return;
    final keyPair = await _ed25519.newKeyPair();
    final data = await keyPair.extract();
    final bytes = Uint8List.fromList([...data.bytes, ...data.publicKey.bytes]);
    await _storage.write(key: _signKeyPrefix + chatId, value: base64Encode(bytes));
  }

  void _validateKeyHex(String keyHex) {
    final t = keyHex.trim();
    if (t.length != 64 || !RegExp(r'^[a-fA-F0-9]+$').hasMatch(t)) {
      throw ArgumentError('Invalid key: expected 64 hex chars');
    }
  }

  Future<void> setQrDismissed(String chatId) async {
    final chats = await getAllChats();
    final i = chats.indexWhere((c) => c.id == chatId);
    if (i < 0) return;
    chats[i] = chats[i].copyWith(qrDismissed: true);
    await _saveChats(chats);
  }

  Future<void> setAutoDeleteAfter(String chatId, int? seconds) async {
    final chats = await getAllChats();
    final i = chats.indexWhere((c) => c.id == chatId);
    if (i < 0) return;
    chats[i] = chats[i].copyWith(autoDeleteAfter: seconds);
    await _saveChats(chats);
  }

  Future<String?> getKeyHex(String chatId) async {
    return _storage.read(key: _keyPrefix + chatId);
  }

  Future<Uint8List?> getKeyBytes(String chatId) async {
    final hex = await getKeyHex(chatId);
    if (hex == null || hex.length != 64) return null;
    return Uint8List.fromList(fromHex(hex));
  }

  /// Room ID for relay (hash of key); server never sees key.
  Future<String?> getRoomId(String chatId) async {
    final key = await getKeyBytes(chatId);
    if (key == null) return null;
    final digest = hashlib.sha256.convert(key);
    return toHex(digest.bytes);
  }

  Future<void> deleteChat(String chatId) async {
    await _deleteChatStorage(chatId);
    final chats = await getAllChats();
    chats.removeWhere((c) => c.id == chatId);
    await _saveChats(chats);
  }

  Future<void> _deleteChatStorage(String chatId) async {
    await _storage.delete(key: _keyPrefix + chatId);
    await _storage.delete(key: _saltPrefix + chatId);
    await _storage.delete(key: _ratchetIndexPrefix + chatId);
    await _storage.delete(key: _chainKeyPrefix + chatId);
    await _storage.delete(key: _signKeyPrefix + chatId);
  }

  /// Deletes ALL chats, keys, ratchet state, and signing keys. Returns roomIds for server wipe.
  Future<List<String>> deleteAll() async {
    final chats = await getAllChats();
    final roomIds = <String>[];
    for (final c in chats) {
      final rid = await getRoomId(c.id);
      if (rid != null) roomIds.add(rid);
      await _deleteChatStorage(c.id);
    }
    await _storage.write(key: _metadataKey, value: jsonEncode({'chats': []}));
    return roomIds;
  }

  // --- Ratchet (forward secrecy) ---
  /// Call before first send/receive if chat was created before ratchet was added.
  Future<void> ensureRatchetAndSigning(String chatId) async {
    if (await getRatchetState(chatId) != null) return;
    await _initRatchet(chatId);
    await _ensureSigningKey(chatId);
  }

  Future<({int index, Uint8List chainKey})?> getRatchetState(String chatId) async {
    final idxStr = await _storage.read(key: _ratchetIndexPrefix + chatId);
    final chainHex = await _storage.read(key: _chainKeyPrefix + chatId);
    if (idxStr == null || chainHex == null || chainHex.length != 64) return null;
    final index = int.tryParse(idxStr) ?? 0;
    return (index: index, chainKey: Uint8List.fromList(fromHex(chainHex)));
  }

  /// Advance send ratchet; returns message key for current index and persists new state.
  Future<Uint8List?> advanceSendRatchet(String chatId) async {
    final state = await getRatchetState(chatId);
    if (state == null) return null;
    final messageKey = Ratchet.messageKey(state.chainKey, state.index);
    final nextChain = Ratchet.nextChainKey(state.chainKey, state.index);
    await _storage.write(key: _ratchetIndexPrefix + chatId, value: '${state.index + 1}');
    await _storage.write(key: _chainKeyPrefix + chatId, value: toHex(nextChain));
    return messageKey;
  }

  /// Advance receive chain to [toIndex] and return message key for that index.
  /// Supports out-of-order: if we already advanced past [toIndex] (e.g. we decrypted a
  /// later message first), the key was cached and is returned from cache.
  Future<Uint8List?> getMessageKeyForReceive(String chatId, int toIndex) async {
    final cache = _receiveMessageKeyCache.putIfAbsent(chatId, () => <int, Uint8List>{});

    // Out-of-order: we already advanced past this index and cached the key.
    final cached = cache.remove(toIndex);
    if (cached != null) return cached;

    final state = await getRatchetState(chatId);
    if (state == null) return null;
    if (toIndex < state.index) return null; // Already advanced, key was not cached (e.g. cache evicted).

    Uint8List chainKey = state.chainKey;
    int index = state.index;

    // Advance step-by-step to [toIndex], caching message keys for skipped indices so
    // later-arriving messages at those indices can be decrypted.
    while (index < toIndex) {
      final msgKey = Ratchet.messageKey(chainKey, index);
      _cacheReceiveKey(chatId, index, msgKey);
      chainKey = Ratchet.nextChainKey(chainKey, index);
      index++;
    }

    final messageKey = Ratchet.messageKey(chainKey, toIndex);
    final nextChain = Ratchet.nextChainKey(chainKey, toIndex);
    await _storage.write(key: _ratchetIndexPrefix + chatId, value: '${toIndex + 1}');
    await _storage.write(key: _chainKeyPrefix + chatId, value: toHex(nextChain));
    return messageKey;
  }

  void _cacheReceiveKey(String chatId, int index, Uint8List key) {
    final cache = _receiveMessageKeyCache[chatId]!;
    cache[index] = key;
    if (cache.length > _maxCachedKeysPerChat) {
      final smallest = cache.keys.reduce((a, b) => a < b ? a : b);
      cache.remove(smallest);
    }
  }

  /// Cache the message key used when sending so we can decrypt our own message when we fetch.
  /// Persisted to secure storage so it survives iOS process kills (in-memory cache is cleared on restart).
  Future<void> cacheSentMessageKey(String chatId, int ratchetIndex, Uint8List messageKey) async {
    final cache = _sentMessageKeyCache.putIfAbsent(chatId, () => <int, Uint8List>{});
    cache[ratchetIndex] = messageKey;
    await _storage.write(
      key: '$_sentKeyPrefix${chatId}_$ratchetIndex',
      value: base64Encode(messageKey),
    );
    if (cache.length > _maxCachedKeysPerChat) {
      final smallest = cache.keys.reduce((a, b) => a < b ? a : b);
      cache.remove(smallest);
      await _storage.delete(key: '$_sentKeyPrefix${chatId}_$smallest');
    }
  }

  /// Get message key we used when sending (memory first, then secure storage for iOS process kill).
  Future<Uint8List?> getSentMessageKey(String chatId, int ratchetIndex) async {
    final fromMemory = _sentMessageKeyCache[chatId]?[ratchetIndex];
    if (fromMemory != null) return fromMemory;
    final stored = await _storage.read(key: '$_sentKeyPrefix${chatId}_$ratchetIndex');
    if (stored == null || stored.isEmpty) return null;
    try {
      final bytes = base64Decode(stored);
      final key = Uint8List.fromList(bytes);
      _sentMessageKeyCache.putIfAbsent(chatId, () => <int, Uint8List>{})[ratchetIndex] = key;
      return key;
    } catch (_) {
      return null;
    }
  }

  /// Get signing key pair for this chat (generates and stores if missing).
  Future<SimpleKeyPair?> getSigningKeyPair(String chatId) async {
    await _ensureSigningKey(chatId);
    final stored = await _storage.read(key: _signKeyPrefix + chatId);
    if (stored == null) return null;
    try {
      final bytes = base64Decode(stored);
      if (bytes.length < 32) return null;
      final seed = bytes.sublist(0, 32);
      return await _ed25519.newKeyPairFromSeed(seed);
    } catch (_) {
      return null;
    }
  }

  /// Relay server base URL for message sync on mobile (e.g. https://xxx.ngrok-free.app). Null on web or when not set.
  Future<String?> getRelayBaseUrl() async => _storage.read(key: _relayUrlKey);

  Future<void> setRelayBaseUrl(String? url) async {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _storage.delete(key: _relayUrlKey);
      return;
    }
    await _storage.write(key: _relayUrlKey, value: trimmed);
  }

  /// Public key bytes (32) for this chat's signing key, for sending to server.
  Future<Uint8List?> getSigningPublicKeyBytes(String chatId) async {
    final keyPair = await getSigningKeyPair(chatId);
    if (keyPair == null) return null;
    final data = await keyPair.extract();
    return Uint8List.fromList(data.publicKey.bytes);
  }
}
