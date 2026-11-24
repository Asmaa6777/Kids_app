import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Parent PIN hashing.
///
/// Why not plain SHA-256 like the prototype? A 4-digit PIN has only 10,000
/// possibilities. With a fast hash, someone who copies the stored value could
/// try all of them in milliseconds. PBKDF2 repeats HMAC-SHA256 many times
/// ([iterations]), which makes each guess slow. A random per-device salt means
/// one precomputed table can't crack every device at once.
///
/// Stored format: `pbkdf2$ITERATIONS$SALT_BASE64$HASH_HEX`.
abstract final class PinHasher {
  static const iterations = 20000;

  static String hash(String pin, {Uint8List? salt, int rounds = iterations}) {
    salt ??= _randomSalt();
    final key = pbkdf2Sha256(utf8.encode(pin), salt, rounds, 32);
    return 'pbkdf2\$$rounds\$${base64Encode(salt)}\$${_hex(key)}';
  }

  static bool verify(String pin, String? stored) {
    if (stored == null) return false;
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final rounds = int.parse(parts[1]);
    final salt = base64Decode(parts[2]);
    final expected = hash(pin, salt: salt, rounds: rounds).split(r'$')[3];
    return _constantTimeEquals(expected, parts[3]);
  }

  /// PBKDF2 (RFC 8018) with HMAC-SHA256, written out so you can see the idea:
  /// U1 = HMAC(pin, salt || blockIndex), Un = HMAC(pin, U(n-1)), result = U1 ^ U2 ^ … ^ Uc.
  static Uint8List pbkdf2Sha256(List<int> password, List<int> salt, int rounds, int length) {
    final hmac = Hmac(sha256, password);
    final out = BytesBuilder();
    for (var block = 1; out.length < length; block++) {
      final blockIndex = [block >> 24 & 0xff, block >> 16 & 0xff, block >> 8 & 0xff, block & 0xff];
      var u = hmac.convert([...salt, ...blockIndex]).bytes;
      final t = Uint8List.fromList(u);
      for (var i = 1; i < rounds; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }
    return Uint8List.sublistView(out.toBytes(), 0, length);
  }

  static Uint8List _randomSalt() {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => r.nextInt(256)));
  }

  static String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Compares every character, so timing doesn't leak how much matched.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
