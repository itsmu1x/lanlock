import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ServerPasswordStore {
  const ServerPasswordStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _saltKey = 'lanlock_server_pw_salt_v1';
  static const _hashKey = 'lanlock_server_pw_hash_v1';
  static const _itersKey = 'lanlock_server_pw_iters_v1';
  static const _encSaltKey = 'lanlock_master_enc_salt_v1';
  static const _encItersKey = 'lanlock_master_enc_iters_v1';

  Future<bool> hasPassword() async {
    final salt = await _storage.read(key: _saltKey);
    final hash = await _storage.read(key: _hashKey);
    return salt != null && hash != null;
  }

  Future<void> setPassword(String password) async {
    final pw = password;
    if (pw.trim().isEmpty) throw ArgumentError('Password cannot be empty');

    final rnd = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => rnd.nextInt(256)),
    );

    const iters = 120000;
    final dk = _pbkdf2HmacSha256(
      password: utf8.encode(pw),
      salt: salt,
      iterations: iters,
      dkLen: 32,
    );

    final encSalt = Uint8List.fromList(
      List<int>.generate(16, (_) => rnd.nextInt(256)),
    );
    const encIters = 210000;

    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _hashKey, value: base64Encode(dk));
    await _storage.write(key: _itersKey, value: iters.toString());
    await _storage.write(key: _encSaltKey, value: base64Encode(encSalt));
    await _storage.write(key: _encItersKey, value: encIters.toString());
  }

  Future<bool> verifyPassword(String password) async {
    final saltB64 = await _storage.read(key: _saltKey);
    final hashB64 = await _storage.read(key: _hashKey);
    final itersStr = await _storage.read(key: _itersKey);
    if (saltB64 == null || hashB64 == null) return false;

    final salt = Uint8List.fromList(base64Decode(saltB64));
    final expected = Uint8List.fromList(base64Decode(hashB64));
    final iters = int.tryParse(itersStr ?? '') ?? 120000;

    final dk = _pbkdf2HmacSha256(
      password: utf8.encode(password),
      salt: salt,
      iterations: iters,
      dkLen: expected.length,
    );

    return _constantTimeEquals(expected, dk);
  }

  Future<Uint8List> deriveEncryptionKey(String password) async {
    final encSaltB64 = await _storage.read(key: _encSaltKey);
    final encItersStr = await _storage.read(key: _encItersKey);
    if (encSaltB64 == null) {
      throw StateError('Master password is not configured.');
    }
    final encSalt = Uint8List.fromList(base64Decode(encSaltB64));
    final encIters = int.tryParse(encItersStr ?? '') ?? 210000;
    return _pbkdf2HmacSha256(
      password: utf8.encode(password),
      salt: encSalt,
      iterations: encIters,
      dkLen: 32,
    );
  }

  // PBKDF2-HMAC-SHA256, RFC 8018.
  static Uint8List _pbkdf2HmacSha256({
    required List<int> password,
    required Uint8List salt,
    required int iterations,
    required int dkLen,
  }) {
    final hLen = crypto.sha256.convert(const <int>[]).bytes.length;
    final l = (dkLen / hLen).ceil();
    final r = dkLen - (l - 1) * hLen;

    final out = BytesBuilder();
    for (var i = 1; i <= l; i++) {
      final block = _f(password, salt, iterations, i);
      out.add(i == l ? block.sublist(0, r) : block);
    }
    return out.toBytes();
  }

  static Uint8List _f(
    List<int> password,
    Uint8List salt,
    int c,
    int blockIndex,
  ) {
    final intBlock = _int32be(blockIndex);
    final u1 = _hmacSha256(password, <int>[...salt, ...intBlock]);
    final t = Uint8List.fromList(u1);

    var uPrev = Uint8List.fromList(u1);
    for (var i = 2; i <= c; i++) {
      final u = _hmacSha256(password, uPrev);
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
      uPrev = Uint8List.fromList(u);
    }
    return t;
  }

  static Uint8List _hmacSha256(List<int> key, List<int> message) {
    final hmac = crypto.Hmac(crypto.sha256, key);
    final digest = hmac.convert(message);
    return Uint8List.fromList(digest.bytes);
  }

  static List<int> _int32be(int i) => <int>[
    (i >> 24) & 0xff,
    (i >> 16) & 0xff,
    (i >> 8) & 0xff,
    i & 0xff,
  ];

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class SessionManager {
  final Map<String, DateTime> _sessions = <String, DateTime>{};

  Duration ttl = const Duration(hours: 8);

  String createSession() {
    final tokenBytes = Uint8List.fromList(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    final token = base64UrlEncode(tokenBytes).replaceAll('=', '');
    _sessions[token] = DateTime.now().toUtc().add(ttl);
    return token;
  }

  bool isValid(String token) {
    final exp = _sessions[token];
    if (exp == null) return false;
    if (DateTime.now().toUtc().isAfter(exp)) {
      _sessions.remove(token);
      return false;
    }
    return true;
  }

  void revoke(String token) {
    _sessions.remove(token);
  }
}
