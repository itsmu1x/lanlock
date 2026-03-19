import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'lanlock_crypto.dart';

class ProfileSummary {
  const ProfileSummary({required this.id, required this.name});

  final int id;
  final String name;
}

class MetaKeySummary {
  const MetaKeySummary({required this.id, required this.keyName});

  final int id;
  final String keyName;
}

class LanlockRepository {
  LanlockRepository({LanlockCrypto? crypto}) : _crypto = crypto ?? LanlockCrypto();

  final LanlockCrypto _crypto;

  static const String _dbName = 'lanlock.db';

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) async {
        await db.execute('''
CREATE TABLE profiles(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  password_ciphertext BLOB NOT NULL,
  password_iv BLOB NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');

        await db.execute('''
CREATE TABLE meta_keys(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  profile_id INTEGER NOT NULL,
  key_name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  UNIQUE(profile_id, key_name),
  FOREIGN KEY(profile_id) REFERENCES profiles(id) ON DELETE CASCADE
);
''');

        await db.execute('''
CREATE TABLE meta_values(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  meta_key_id INTEGER NOT NULL UNIQUE,
  value_ciphertext BLOB NOT NULL,
  value_iv BLOB NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(meta_key_id) REFERENCES meta_keys(id) ON DELETE CASCADE
);
''');

        await db.execute('CREATE INDEX idx_meta_keys_profile ON meta_keys(profile_id)');
      },
    );
  }

  Future<List<ProfileSummary>> searchProfiles(String query) async {
    final db = await database;
    final q = query.trim();

    final rows = q.isEmpty
        ? await db.query(
            'profiles',
            columns: const ['id', 'name'],
            orderBy: 'name COLLATE NOCASE ASC',
          )
        : await db.query(
            'profiles',
            columns: const ['id', 'name'],
            where: 'name LIKE ?',
            whereArgs: ['%$q%'],
            orderBy: 'name COLLATE NOCASE ASC',
          );

    return rows
        .map((r) => ProfileSummary(id: r['id'] as int, name: r['name'] as String))
        .toList();
  }

  Future<ProfileSummary?> getProfile(int profileId) async {
    final db = await database;
    final rows = await db.query(
      'profiles',
      columns: const ['id', 'name'],
      where: 'id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ProfileSummary(id: r['id'] as int, name: r['name'] as String);
  }

  Future<int> createProfile({
    required String name,
    required String password,
    required Map<String, String> metadata,
  }) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final encryptedPassword = await _crypto.encryptString(password);

      final profileId = await txn.insert(
        'profiles',
        {
          'name': name.trim(),
          'password_ciphertext': encryptedPassword.ciphertext,
          'password_iv': encryptedPassword.iv,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.fail,
      );

      for (final entry in metadata.entries) {
        final keyName = entry.key.trim();
        if (keyName.isEmpty) continue;

        final metaNow = DateTime.now().millisecondsSinceEpoch;
        final metaKeyId = await txn.insert(
          'meta_keys',
          {
            'profile_id': profileId,
            'key_name': keyName,
            'created_at': metaNow,
            'updated_at': metaNow,
          },
          conflictAlgorithm: ConflictAlgorithm.fail,
        );

        final encryptedValue = await _crypto.encryptString(entry.value);
        await txn.insert(
          'meta_values',
          {
            'meta_key_id': metaKeyId,
            'value_ciphertext': encryptedValue.ciphertext,
            'value_iv': encryptedValue.iv,
            'created_at': metaNow,
            'updated_at': metaNow,
          },
          conflictAlgorithm: ConflictAlgorithm.fail,
        );
      }

      return profileId;
    });
  }

  Future<List<MetaKeySummary>> listMetaKeys(int profileId) async {
    final db = await database;
    final rows = await db.query(
      'meta_keys',
      columns: const ['id', 'key_name'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'key_name COLLATE NOCASE ASC',
    );

    return rows
        .map((r) => MetaKeySummary(id: r['id'] as int, keyName: r['key_name'] as String))
        .toList();
  }

  Future<String> decryptProfilePassword(int profileId) async {
    final db = await database;
    final rows = await db.query(
      'profiles',
      columns: const ['password_ciphertext', 'password_iv'],
      where: 'id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Profile not found');

    final r = rows.first;
    final payload = LanlockEncryptedBytes(
      ciphertext: r['password_ciphertext'] as Uint8List,
      iv: r['password_iv'] as Uint8List,
    );
    return _crypto.decryptString(payload);
  }

  Future<void> updateProfilePassword({
    required int profileId,
    required String newPassword,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final encryptedPassword = await _crypto.encryptString(newPassword);

    await db.update(
      'profiles',
      {
        'password_ciphertext': encryptedPassword.ciphertext,
        'password_iv': encryptedPassword.iv,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [profileId],
    );
  }

  Future<String> decryptMetaKeyValue(int metaKeyId) async {
    final db = await database;
    final rows = await db.query(
      'meta_values',
      columns: const ['value_ciphertext', 'value_iv'],
      where: 'meta_key_id = ?',
      whereArgs: [metaKeyId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Meta value not found');

    final r = rows.first;
    final payload = LanlockEncryptedBytes(
      ciphertext: r['value_ciphertext'] as Uint8List,
      iv: r['value_iv'] as Uint8List,
    );

    return _crypto.decryptString(payload);
  }

  Future<int> getOrCreateMetaKeyId({
    required int profileId,
    required String keyName,
  }) async {
    final db = await database;
    final trimmed = keyName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Meta key name cannot be empty');

    final rows = await db.query(
      'meta_keys',
      columns: const ['id'],
      where: 'profile_id = ? AND key_name = ?',
      whereArgs: [profileId, trimmed],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;

    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert(
      'meta_keys',
      {
        'profile_id': profileId,
        'key_name': trimmed,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  Future<void> upsertMetaKeyValue({
    required int profileId,
    required String keyName,
    required String value,
  }) async {
    final db = await database;
    final metaKeyId = await getOrCreateMetaKeyId(profileId: profileId, keyName: keyName);
    final encryptedValue = await _crypto.encryptString(value);
    final now = DateTime.now().millisecondsSinceEpoch;

    final updated = await db.update(
      'meta_values',
      {
        'value_ciphertext': encryptedValue.ciphertext,
        'value_iv': encryptedValue.iv,
        'updated_at': now,
      },
      where: 'meta_key_id = ?',
      whereArgs: [metaKeyId],
    );

    if (updated == 0) {
      await db.insert(
        'meta_values',
        {
          'meta_key_id': metaKeyId,
          'value_ciphertext': encryptedValue.ciphertext,
          'value_iv': encryptedValue.iv,
          'created_at': now,
          'updated_at': now,
        },
      );
    }
  }

  Future<void> updateMetaKeyAndValue({
    required int metaKeyId,
    required String newKeyName,
    required String newValue,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final encryptedValue = await _crypto.encryptString(newValue);

    await db.update(
      'meta_keys',
      {
        'key_name': newKeyName.trim(),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [metaKeyId],
    );

    await db.update(
      'meta_values',
      {
        'value_ciphertext': encryptedValue.ciphertext,
        'value_iv': encryptedValue.iv,
        'updated_at': now,
      },
      where: 'meta_key_id = ?',
      whereArgs: [metaKeyId],
    );
  }
}

