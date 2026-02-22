import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/relay_config.dart';
import 'encryption_service.dart';
import 'chat_repository.dart';

/// Encrypted chat with ratcheting, sender verification, and optional TTL.
class ChatService {
  final ChatRepository _repo = ChatRepository();
  static final _ed25519 = Ed25519();
  /// Cache decrypted messages by "ratchetIndex|at" so we don't re-advance ratchet on poll.
  static final Map<String, Map<String, Map<String, dynamic>>> _decryptCache = {};

  /// Base URI for the relay API. On web uses current origin; on mobile uses stored relay URL or [kDefaultRelayBaseUrl].
  Future<Uri?> _apiBase() async {
    if (kIsWeb) return Uri.base;
    final url = await _repo.getRelayBaseUrl() ?? kDefaultRelayBaseUrl;
    if (url.isEmpty) return null;
    return Uri.tryParse(url);
  }

  Future<void> addMessage({
    required String chatId,
    required String text,
    required bool isMe,
    required String senderAlias,
    int? expiresIn,
  }) async {
    final roomId = await _repo.getRoomId(chatId);
    if (roomId == null) throw StateError('No room');

    await _repo.ensureRatchetAndSigning(chatId);
    final stateBefore = await _repo.getRatchetState(chatId);
    if (stateBefore == null) throw StateError('Ratchet not initialized');
    final messageKey = await _repo.advanceSendRatchet(chatId);
    if (messageKey == null) throw StateError('Ratchet not initialized');

    final ratchetIndexUsed = stateBefore.index;
    await _repo.cacheSentMessageKey(chatId, ratchetIndexUsed, messageKey);

    final at = DateTime.now().toIso8601String();
    final encrypted = await EncryptionService.encrypt(text, messageKey);

    final keyPair = await _repo.getSigningKeyPair(chatId);
    if (keyPair == null) throw StateError('No signing key');

    final payload = '$chatId|$at|$encrypted';
    final signature = await _ed25519.sign(
      utf8.encode(payload),
      keyPair: keyPair,
    );
    final signatureB64 = base64Encode(signature.bytes);

    final base = await _apiBase();
    if (base != null) {
      try {
        final uri = base.replace(path: '/api/messages');
        await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'roomId': roomId,
            'encrypted': encrypted,
            'isMe': isMe,
            'at': at,
            'ratchetIndex': ratchetIndexUsed,
            'senderAlias': senderAlias,
            'signature': signatureB64,
            if (expiresIn != null && expiresIn > 0) 'expiresIn': expiresIn,
          }),
        );
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final roomId = await _repo.getRoomId(chatId);
    if (roomId == null) return [];
    await _repo.ensureRatchetAndSigning(chatId);

    final base = await _apiBase();
    if (base != null) {
      try {
        final uri = base.replace(
          path: '/api/messages',
          queryParameters: {'roomId': roomId},
        );
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          final list = jsonDecode(res.body) as List;
          final participants = await getParticipantsWithKeys(chatId);
          final maps = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          int toIndex(dynamic r) => r is int ? r : (r is num ? r.toInt() : int.tryParse(r?.toString() ?? '0') ?? 0);
          maps.sort((a, b) => toIndex(a['ratchetIndex']).compareTo(toIndex(b['ratchetIndex'])));
          final cache = _decryptCache.putIfAbsent(chatId, () => <String, Map<String, dynamic>>{});
          final out = <Map<String, dynamic>>[];
          for (final map in maps) {
            final enc = map['encrypted'] as String?;
            final ratchetIndex = toIndex(map['ratchetIndex']);
            final at = map['at'] as String? ?? '';
            if (enc == null) continue;
            final cacheKey = '${ratchetIndex}_$at';
            final cached = cache[cacheKey];
            if (cached != null) {
              out.add(cached);
              continue;
            }
            try {
              Uint8List? messageKey = await _repo.getMessageKeyForReceive(chatId, ratchetIndex);
              messageKey ??= await _repo.getSentMessageKey(chatId, ratchetIndex);
              if (messageKey == null) continue;
              final text = await EncryptionService.decrypt(enc, messageKey);
              final senderAlias = map['senderAlias'] as String? ?? '';
              final sigB64 = map['signature'] as String?;
              bool verified = false;
              if (sigB64 != null && senderAlias.isNotEmpty) {
                final pubKey = participants[senderAlias];
                if (pubKey != null && pubKey.length == 32) {
                  try {
                    final sig = Signature(
                      base64Decode(sigB64),
                      publicKey: SimplePublicKey(pubKey, type: KeyPairType.ed25519),
                    );
                    final payload = '$chatId|$at|$enc';
                    verified = await _ed25519.verify(
                      utf8.encode(payload),
                      signature: sig,
                    );
                  } catch (_) {}
                }
              }
              final decrypted = {
                'text': text,
                'isMe': map['isMe'] == true,
                'at': at,
                'senderAlias': senderAlias,
                'verified': verified,
              };
              cache[cacheKey] = decrypted;
              out.add(decrypted);
            } catch (_) {}
          }
          out.sort((a, b) => (a['at'] as String).compareTo(b['at'] as String));
          return out;
        }
      } catch (_) {}
    }
    return [];
  }

  /// Register as participant with public key for sender verification.
  Future<void> joinRoom(String chatId, String alias) async {
    final roomId = await _repo.getRoomId(chatId);
    if (roomId == null) return;
    final publicKeyBytes = await _repo.getSigningPublicKeyBytes(chatId);
    final base = await _apiBase();
    if (base == null) return;
    try {
      final uri = base.replace(path: '/api/participants');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'roomId': roomId,
          'alias': alias,
          'publicKey': publicKeyBytes != null ? base64Encode(publicKeyBytes) : '',
        }),
      );
    } catch (_) {}
  }

  Future<List<String>> getParticipants(String chatId) async {
    final list = await getParticipantsWithKeys(chatId);
    return list.keys.toList();
  }

  /// alias -> publicKey bytes (32) for signature verification.
  Future<Map<String, List<int>>> getParticipantsWithKeys(String chatId) async {
    final roomId = await _repo.getRoomId(chatId);
    if (roomId == null) return {};
    final base = await _apiBase();
    if (base == null) return {};
    try {
      final uri = base.replace(
        path: '/api/participants',
        queryParameters: {'roomId': roomId},
      );
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final out = <String, List<int>>{};
        for (final e in list) {
          final map = Map<String, dynamic>.from(e as Map);
          final alias = map['alias'] as String? ?? '';
          final pkB64 = map['publicKey'] as String?;
          if (alias.isEmpty) continue;
          if (pkB64 != null && pkB64.isNotEmpty) {
            try {
              out[alias] = base64Decode(pkB64);
            } catch (_) {}
          } else {
            out[alias] = [];
          }
        }
        return out;
      }
    } catch (_) {}
    return {};
  }

  /// Tell server to wipe messages and participants for these room IDs (panic button).
  Future<void> wipeRooms(List<String> roomIds) async {
    if (roomIds.isEmpty) return;
    final base = await _apiBase();
    if (base == null) return;
    try {
      final uri = base.replace(path: '/api/wipe');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'roomIds': roomIds}),
      );
    } catch (_) {}
  }
}
