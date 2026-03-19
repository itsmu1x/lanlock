import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LanlockEncryptedBytes {
  LanlockEncryptedBytes({
    required this.ciphertext,
    required this.iv,
  });

  final Uint8List ciphertext;
  final Uint8List iv;
}

class LanlockCrypto {
  LanlockCrypto({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _aesKeyStorageKey = 'lanlock_aes_key_v1';

  final FlutterSecureStorage _storage;

  encrypt.Key? _cachedKey;

  Future<encrypt.Key> _getOrCreateAesKey() async {
    if (_cachedKey != null) return _cachedKey!;

    final stored = await _storage.read(key: _aesKeyStorageKey);
    if (stored != null) {
      final keyBytes = base64Decode(stored);
      _cachedKey = encrypt.Key(Uint8List.fromList(keyBytes));
      return _cachedKey!;
    }

    final rnd = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    final key = encrypt.Key(Uint8List.fromList(keyBytes));
    await _storage.write(key: _aesKeyStorageKey, value: base64Encode(keyBytes));
    _cachedKey = key;
    return key;
  }

  Future<LanlockEncryptedBytes> encryptString(String plaintext) async {
    final key = await _getOrCreateAesKey();

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
    final key = await _getOrCreateAesKey();

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

