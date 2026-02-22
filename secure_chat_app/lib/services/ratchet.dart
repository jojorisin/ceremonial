import 'dart:typed_data';

import 'package:hashlib/hashlib.dart' as hashlib;

/// Forward-secrecy ratchet: each message uses a new key derived from the previous.
/// chainKey_0 = KDF(masterKey), then messageKey_i = KDF(chainKey_i, "msg", i), chainKey_{i+1} = KDF(chainKey_i, "chain", i).
class Ratchet {
  static const _domainChain = 'ratchet-chain-v1';
  static const _domainMsg = 'ratchet-msg-v1';

  /// Derive initial chain key from master key (32 bytes).
  static Uint8List initialChainKey(Uint8List masterKey) {
    if (masterKey.length != 32) throw ArgumentError('masterKey must be 32 bytes');
    final input = Uint8List.fromList([
      ...masterKey,
      ..._domainChain.codeUnits,
      0,
    ]);
    return Uint8List.fromList(hashlib.sha256.convert(input).bytes);
  }

  /// Derive message key for index i from current chain key (32 bytes each).
  static Uint8List messageKey(Uint8List chainKey, int index) {
    if (chainKey.length != 32) throw ArgumentError('chainKey must be 32 bytes');
    final input = Uint8List.fromList([
      ...chainKey,
      ..._domainMsg.codeUnits,
      ..._uint64(index),
    ]);
    return Uint8List.fromList(hashlib.sha256.convert(input).bytes);
  }

  /// Derive next chain key from current chain key and index.
  static Uint8List nextChainKey(Uint8List chainKey, int index) {
    if (chainKey.length != 32) throw ArgumentError('chainKey must be 32 bytes');
    final input = Uint8List.fromList([
      ...chainKey,
      ..._domainChain.codeUnits,
      ..._uint64(index + 1),
    ]);
    return Uint8List.fromList(hashlib.sha256.convert(input).bytes);
  }

  static List<int> _uint64(int i) {
    final b = List<int>.filled(8, 0);
    for (int j = 0; j < 8 && i != 0; j++) {
      b[j] = i & 0xff;
      i >>= 8;
    }
    return b;
  }
}
