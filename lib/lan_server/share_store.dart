import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// In-memory + temp-file hub for LAN-only text/file sharing (not password DB).
class LanShareStore extends ChangeNotifier {
  LanShareStore({String? tempSubdir}) : _tempSubdir = tempSubdir ?? 'lanlock_lan_share';

  static const int maxItems = 80;
  static const int maxFileBytes = 48 * 1024 * 1024; // 48 MB

  final String _tempSubdir;
  final List<ShareItem> _items = [];

  Future<Directory> _ensureDir() async {
    final base = Directory.systemTemp;
    final dir = Directory(p.join(base.path, _tempSubdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _newId() {
    final t = DateTime.now().microsecondsSinceEpoch;
    final r = Random.secure().nextInt(1 << 30);
    return '${t}_$r';
  }

  void _trim() {
    while (_items.length > maxItems) {
      final old = _items.removeAt(0);
      if (old.kind == ShareKind.file && old.filePath != null) {
        try {
          final f = File(old.filePath!);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Add plain text entry (copy-friendly on clients).
  ShareItem addText(String text) {
    final t = text;
    if (t.length > 2 * 1024 * 1024) {
      throw ArgumentError('Text too large (max ~2 MB).');
    }
    final item = ShareItem(
      id: _newId(),
      kind: ShareKind.text,
      text: t,
      label: 'Text',
      sizeBytes: t.length,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _items.add(item);
    _trim();
    notifyListeners();
    return item;
  }

  /// Save uploaded bytes to a temp file and register.
  Future<ShareItem> addFile(Uint8List bytes, String filename) async {
    if (bytes.length > maxFileBytes) {
      throw ArgumentError('File too large (max 48 MB).');
    }
    final safeName = filename.replaceAll(RegExp(r'[^\w.\-()\s]'), '_').trim();
    final name = safeName.isEmpty ? 'file.bin' : p.basename(safeName);
    final dir = await _ensureDir();
    final id = _newId();
    final path = p.join(dir.path, '${id}_$name');
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    final item = ShareItem(
      id: id,
      kind: ShareKind.file,
      filePath: path,
      label: name,
      sizeBytes: bytes.length,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _items.add(item);
    _trim();
    notifyListeners();
    return item;
  }

  List<ShareItem> list() => List.unmodifiable(_items.reversed);

  ShareItem? get(String id) {
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  bool remove(String id) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return false;
    final old = _items.removeAt(idx);
    if (old.kind == ShareKind.file && old.filePath != null) {
      try {
        final f = File(old.filePath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    notifyListeners();
    return true;
  }

  void clear() {
    final copy = List<ShareItem>.from(_items);
    _items.clear();
    for (final e in copy) {
      if (e.kind == ShareKind.file && e.filePath != null) {
        try {
          final f = File(e.filePath!);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
    notifyListeners();
  }
}

enum ShareKind { text, file }

class ShareItem {
  ShareItem({
    required this.id,
    required this.kind,
    this.text,
    this.filePath,
    required this.label,
    required this.sizeBytes,
    required this.createdAtMs,
  });

  final String id;
  final ShareKind kind;
  final String? text;
  final String? filePath;
  final String label;
  final int sizeBytes;
  final int createdAtMs;

  Map<String, dynamic> toJsonSummary() => {
        'id': id,
        'kind': kind == ShareKind.text ? 'text' : 'file',
        'label': label,
        'sizeBytes': sizeBytes,
        'createdAtMs': createdAtMs,
      };
}
