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

enum HomeItemKind { spacer, profile }

/// One row in the vault home screen (section header or password entry).
class HomeLayoutRow {
  const HomeLayoutRow({
    required this.homeItemId,
    required this.kind,
    this.spacerId,
    this.spacerTitle,
    this.profileId,
    this.profileName,
  });

  final int homeItemId;
  final HomeItemKind kind;
  final int? spacerId;
  final String? spacerTitle;
  final int? profileId;
  final String? profileName;
}

class LanlockRepository {
  LanlockRepository({LanlockCrypto? crypto})
    : _crypto = crypto ?? LanlockCrypto();

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
      version: 3,
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
  sort_order INTEGER NOT NULL DEFAULT 0,
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

        await db.execute(
          'CREATE INDEX idx_meta_keys_profile ON meta_keys(profile_id)',
        );

        await db.execute('''
CREATE TABLE spacers(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL DEFAULT ''
);
''');

        await db.execute('''
CREATE TABLE home_items(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sort_order INTEGER NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('spacer', 'profile')),
  spacer_id INTEGER,
  profile_id INTEGER,
  FOREIGN KEY(spacer_id) REFERENCES spacers(id) ON DELETE CASCADE,
  FOREIGN KEY(profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CHECK(
    (kind = 'spacer' AND spacer_id IS NOT NULL AND profile_id IS NULL) OR
    (kind = 'profile' AND profile_id IS NOT NULL AND spacer_id IS NULL)
  )
);
''');

        await db.execute(
          'CREATE UNIQUE INDEX idx_home_items_profile ON home_items(profile_id) WHERE profile_id IS NOT NULL',
        );
        await db.execute(
          'CREATE UNIQUE INDEX idx_home_items_spacer ON home_items(spacer_id) WHERE spacer_id IS NOT NULL',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE profiles ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
          );
          final rows = await db.query(
            'profiles',
            columns: const ['id'],
            orderBy: 'name COLLATE NOCASE ASC',
          );
          final now = DateTime.now().millisecondsSinceEpoch;
          var i = 0;
          for (final r in rows) {
            await db.update(
              'profiles',
              {'sort_order': i, 'updated_at': now},
              where: 'id = ?',
              whereArgs: [r['id']],
            );
            i++;
          }
        }
        if (oldVersion < 3) {
          await db.execute('''
CREATE TABLE spacers(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL DEFAULT ''
);
''');
          await db.execute('''
CREATE TABLE home_items(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sort_order INTEGER NOT NULL,
  kind TEXT NOT NULL CHECK(kind IN ('spacer', 'profile')),
  spacer_id INTEGER,
  profile_id INTEGER,
  FOREIGN KEY(spacer_id) REFERENCES spacers(id) ON DELETE CASCADE,
  FOREIGN KEY(profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
  CHECK(
    (kind = 'spacer' AND spacer_id IS NOT NULL AND profile_id IS NULL) OR
    (kind = 'profile' AND profile_id IS NOT NULL AND spacer_id IS NULL)
  )
);
''');
          await db.execute(
            'CREATE UNIQUE INDEX idx_home_items_profile ON home_items(profile_id) WHERE profile_id IS NOT NULL',
          );
          await db.execute(
            'CREATE UNIQUE INDEX idx_home_items_spacer ON home_items(spacer_id) WHERE spacer_id IS NOT NULL',
          );
          final rows = await db.query(
            'profiles',
            columns: const ['id'],
            orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
          );
          var i = 0;
          for (final r in rows) {
            await db.insert('home_items', {
              'sort_order': i,
              'kind': 'profile',
              'spacer_id': null,
              'profile_id': r['id'],
            });
            i++;
          }
        }
      },
    );
  }

  Future<void> _ensureHomeLayoutCoversAllProfiles(Database db) async {
    final profileRows = await db.query('profiles', columns: const ['id']);
    if (profileRows.isEmpty) return;
    final homeRows = await db.query(
      'home_items',
      columns: const ['profile_id'],
      where: 'kind = ?',
      whereArgs: const ['profile'],
    );
    final covered = <int>{
      for (final r in homeRows)
        if (r['profile_id'] != null) r['profile_id'] as int,
    };
    final missing = <int>[];
    for (final r in profileRows) {
      final id = r['id'] as int;
      if (!covered.contains(id)) missing.add(id);
    }
    if (missing.isEmpty) return;

    final maxRows = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) AS m FROM home_items',
    );
    var o = (maxRows.first['m'] as int) + 1;
    await db.transaction((txn) async {
      for (final id in missing) {
        await txn.insert('home_items', {
          'sort_order': o,
          'kind': 'profile',
          'spacer_id': null,
          'profile_id': id,
        });
        o++;
      }
    });
  }

  /// Ordered mix of spacers and profiles for the home screen and web UI.
  Future<List<HomeLayoutRow>> loadHomeLayout() async {
    final db = await database;
    await _ensureHomeLayoutCoversAllProfiles(db);
    final rows = await db.rawQuery('''
SELECT
  hi.id AS home_item_id,
  hi.kind AS kind,
  hi.spacer_id AS spacer_id,
  hi.profile_id AS profile_id,
  s.title AS spacer_title,
  p.name AS profile_name
FROM home_items hi
LEFT JOIN spacers s ON s.id = hi.spacer_id
LEFT JOIN profiles p ON p.id = hi.profile_id
ORDER BY hi.sort_order ASC, hi.id ASC
''');

    return rows.map((r) {
      final kindStr = r['kind'] as String;
      final kind = kindStr == 'spacer'
          ? HomeItemKind.spacer
          : HomeItemKind.profile;
      return HomeLayoutRow(
        homeItemId: r['home_item_id'] as int,
        kind: kind,
        spacerId: r['spacer_id'] as int?,
        spacerTitle: r['spacer_title'] as String?,
        profileId: r['profile_id'] as int?,
        profileName: r['profile_name'] as String?,
      );
    }).toList();
  }

  Future<void> reorderHomeLayout(List<int> homeItemIdsInOrder) async {
    if (homeItemIdsInOrder.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < homeItemIdsInOrder.length; i++) {
        await txn.update(
          'home_items',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [homeItemIdsInOrder[i]],
        );
      }
    });
  }

  Future<int> createSpacer({required String title}) async {
    final db = await database;
    final trimmed = title.trim();
    return db.transaction<int>((txn) async {
      final spacerId = await txn.insert('spacers', {'title': trimmed});
      final maxRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) AS m FROM home_items',
      );
      final nextOrder = (maxRows.first['m'] as int) + 1;
      await txn.insert('home_items', {
        'sort_order': nextOrder,
        'kind': 'spacer',
        'spacer_id': spacerId,
        'profile_id': null,
      });
      return spacerId;
    });
  }

  Future<void> updateSpacerTitle({
    required int spacerId,
    required String title,
  }) async {
    final db = await database;
    final n = await db.update(
      'spacers',
      {'title': title.trim()},
      where: 'id = ?',
      whereArgs: [spacerId],
    );
    if (n == 0) throw StateError('Spacer not found');
  }

  Future<void> deleteSpacer(int spacerId) async {
    final db = await database;
    final n = await db.delete(
      'spacers',
      where: 'id = ?',
      whereArgs: [spacerId],
    );
    if (n == 0) throw StateError('Spacer not found');
  }

  Future<List<ProfileSummary>> searchProfiles(String query) async {
    final db = await database;
    final q = query.trim();

    final rows = q.isEmpty
        ? await db.query(
            'profiles',
            columns: const ['id', 'name'],
            orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
          )
        : await db.query(
            'profiles',
            columns: const ['id', 'name'],
            where: 'name LIKE ?',
            whereArgs: ['%$q%'],
            orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
          );

    return rows
        .map(
          (r) => ProfileSummary(id: r['id'] as int, name: r['name'] as String),
        )
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

  /// Deletes the profile and all its metadata (SQLite foreign key CASCADE).
  Future<void> deleteProfile(int profileId) async {
    final db = await database;
    final n = await db.delete(
      'profiles',
      where: 'id = ?',
      whereArgs: [profileId],
    );
    if (n == 0) throw StateError('Profile not found');
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

      final maxRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) AS m FROM profiles',
      );
      final nextProfileOrder = (maxRows.first['m'] as int) + 1;

      final profileId = await txn.insert('profiles', {
        'name': name.trim(),
        'password_ciphertext': encryptedPassword.ciphertext,
        'password_iv': encryptedPassword.iv,
        'sort_order': nextProfileOrder,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.fail);

      final maxHome = await txn.rawQuery(
        'SELECT COALESCE(MAX(sort_order), -1) AS m FROM home_items',
      );
      final nextHomeOrder = (maxHome.first['m'] as int) + 1;
      await txn.insert('home_items', {
        'sort_order': nextHomeOrder,
        'kind': 'profile',
        'spacer_id': null,
        'profile_id': profileId,
      });

      for (final entry in metadata.entries) {
        final keyName = entry.key.trim();
        if (keyName.isEmpty) continue;

        final metaNow = DateTime.now().millisecondsSinceEpoch;
        final metaKeyId = await txn.insert('meta_keys', {
          'profile_id': profileId,
          'key_name': keyName,
          'created_at': metaNow,
          'updated_at': metaNow,
        }, conflictAlgorithm: ConflictAlgorithm.fail);

        final encryptedValue = await _crypto.encryptString(entry.value);
        await txn.insert('meta_values', {
          'meta_key_id': metaKeyId,
          'value_ciphertext': encryptedValue.ciphertext,
          'value_iv': encryptedValue.iv,
          'created_at': metaNow,
          'updated_at': metaNow,
        }, conflictAlgorithm: ConflictAlgorithm.fail);
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
        .map(
          (r) => MetaKeySummary(
            id: r['id'] as int,
            keyName: r['key_name'] as String,
          ),
        )
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

  /// Changes the display name (must stay unique across profiles).
  Future<void> updateProfileName({
    required int profileId,
    required String newName,
  }) async {
    final db = await database;
    final trimmed = newName.trim();
    if (trimmed.isEmpty) throw ArgumentError('Name cannot be empty');

    final self = await getProfile(profileId);
    if (self == null) throw StateError('Profile not found');
    if (self.name == trimmed) return;

    final other = await _findProfileByName(trimmed);
    if (other != null && other.id != profileId) {
      throw StateError('Another entry already uses this name.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final n = await db.update(
      'profiles',
      {'name': trimmed, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [profileId],
    );
    if (n == 0) throw StateError('Profile not found');
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
    return db.insert('meta_keys', {
      'profile_id': profileId,
      'key_name': trimmed,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.fail);
  }

  Future<void> upsertMetaKeyValue({
    required int profileId,
    required String keyName,
    required String value,
  }) async {
    final db = await database;
    final metaKeyId = await getOrCreateMetaKeyId(
      profileId: profileId,
      keyName: keyName,
    );
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
      await db.insert('meta_values', {
        'meta_key_id': metaKeyId,
        'value_ciphertext': encryptedValue.ciphertext,
        'value_iv': encryptedValue.iv,
        'created_at': now,
        'updated_at': now,
      });
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
      {'key_name': newKeyName.trim(), 'updated_at': now},
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

  /// Removes a metadata key and its encrypted value (CASCADE on meta_values).
  Future<void> deleteMetaKey(int metaKeyId) async {
    final db = await database;
    final n = await db.delete(
      'meta_keys',
      where: 'id = ?',
      whereArgs: [metaKeyId],
    );
    if (n == 0) throw StateError('Metadata key not found');
  }

  Future<Map<String, dynamic>> exportBackupPayload() async {
    final db = await database;
    await _ensureHomeLayoutCoversAllProfiles(db);
    final orderedIds = await db.rawQuery('''
SELECT hi.profile_id AS pid, p.name AS name
FROM home_items hi
JOIN profiles p ON p.id = hi.profile_id
WHERE hi.kind = 'profile'
ORDER BY hi.sort_order ASC, hi.id ASC
''');

    final profiles = <Map<String, dynamic>>[];
    for (final row in orderedIds) {
      final profileId = row['pid'] as int;
      final name = row['name'] as String;
      final password = await decryptProfilePassword(profileId);

      final metaRows = await db.rawQuery(
        '''
SELECT mk.id AS mk_id, mk.key_name AS key_name
FROM meta_keys mk
WHERE mk.profile_id = ?
ORDER BY mk.key_name COLLATE NOCASE ASC
''',
        [profileId],
      );

      final metadata = <Map<String, String>>[];
      for (final mk in metaRows) {
        final metaKeyId = mk['mk_id'] as int;
        final keyName = mk['key_name'] as String;
        final value = await decryptMetaKeyValue(metaKeyId);
        metadata.add({'key': keyName, 'value': value});
      }

      profiles.add({'name': name, 'password': password, 'metadata': metadata});
    }

    return {
      'format': 'lanlock-backup-v1',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'profiles': profiles,
    };
  }

  Future<Map<String, int>> importBackupPayload(
    Map<String, dynamic> payload, {
    required bool replaceExisting,
  }) async {
    final profilesRaw = payload['profiles'];
    if (profilesRaw is! List) {
      throw ArgumentError('Invalid backup: "profiles" must be a list.');
    }

    var imported = 0;
    var skipped = 0;
    var failed = 0;

    for (final item in profilesRaw) {
      try {
        if (item is! Map<String, dynamic>) {
          failed++;
          continue;
        }
        final name = (item['name'] as String? ?? '').trim();
        final password = item['password'] as String? ?? '';
        if (name.isEmpty || password.isEmpty) {
          failed++;
          continue;
        }

        final metadata = <String, String>{};
        final metaRaw = item['metadata'];
        if (metaRaw is List) {
          for (final mk in metaRaw) {
            if (mk is! Map<String, dynamic>) continue;
            final key = (mk['key'] as String? ?? '').trim();
            final value = mk['value'] as String? ?? '';
            if (key.isEmpty) continue;
            metadata[key] = value;
          }
        }

        final existing = await _findProfileByName(name);
        if (existing == null) {
          await createProfile(
            name: name,
            password: password,
            metadata: metadata,
          );
          imported++;
          continue;
        }

        if (!replaceExisting) {
          skipped++;
          continue;
        }

        await updateProfilePassword(
          profileId: existing.id,
          newPassword: password,
        );
        for (final entry in metadata.entries) {
          await upsertMetaKeyValue(
            profileId: existing.id,
            keyName: entry.key,
            value: entry.value,
          );
        }
        imported++;
      } catch (_) {
        failed++;
      }
    }

    return {
      'imported': imported,
      'skipped': skipped,
      'failed': failed,
      'total': profilesRaw.length,
    };
  }

  Future<ProfileSummary?> _findProfileByName(String name) async {
    final db = await database;
    final rows = await db.query(
      'profiles',
      columns: const ['id', 'name'],
      where: 'name = ?',
      whereArgs: [name.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ProfileSummary(id: r['id'] as int, name: r['name'] as String);
  }
}
