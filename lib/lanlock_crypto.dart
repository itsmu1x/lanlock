import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LanlockEncryptedBytes {
  LanlockEncryptedBytes({required this.ciphertext, required this.iv});

  final Uint8List ciphertext;
  final Uint8List iv;
}

class LanlockCrypto {
  static Uint8List? _activeSessionKey;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _persistedSessionKeyStorageKey =
      'lanlock_persisted_session_key_v1';

  static bool get isUnlocked => _activeSessionKey != null;

  static void setSessionKey(Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError('Session key must be 32 bytes.');
    }
    _activeSessionKey = Uint8List.fromList(key);
  }

  static Future<void> persistSessionKey(Uint8List key) async {
    if (key.length != 32) {
      throw ArgumentError('Session key must be 32 bytes.');
    }
    await _storage.write(
      key: _persistedSessionKeyStorageKey,
      value: base64Encode(key),
    );
  }

  static Future<bool> tryRestoreSessionKey() async {
    final encoded = await _storage.read(key: _persistedSessionKeyStorageKey);
    if (encoded == null || encoded.trim().isEmpty) return false;
    final bytes = base64Decode(encoded);
    if (bytes.length != 32) return false;
    _activeSessionKey = Uint8List.fromList(bytes);
    return true;
  }

  static Future<void> clearPersistedSessionKey() async {
    await _storage.delete(key: _persistedSessionKeyStorageKey);
  }

  static void clearSessionKey() {
    _activeSessionKey = null;
  }

  Future<encrypt.Key> _requireAesKey() async {
    final key = _activeSessionKey;
    if (key == null) {
      throw StateError('Master password is required. Unlock the app first.');
    }
    return encrypt.Key(Uint8List.fromList(key));
  }

  Future<LanlockEncryptedBytes> encryptString(String plaintext) async {
    final key = await _requireAesKey();

    final rnd = Random.secure();
    final ivBytes = List<int>.generate(16, (_) => rnd.nextInt(256));

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );

    final iv = encrypt.IV(Uint8List.fromList(ivBytes));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    return LanlockEncryptedBytes(
      ciphertext: Uint8List.fromList(encrypted.bytes),
      iv: Uint8List.fromList(ivBytes),
    );
  }

  Future<String> decryptString(LanlockEncryptedBytes payload) async {
    final key = await _requireAesKey();

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );

    final iv = encrypt.IV(payload.iv);
    final decrypted = encrypter.decrypt(
      encrypt.Encrypted(payload.ciphertext),
      iv: iv,
    );
    return decrypted;
  }
}
