import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../lanlock_repository.dart';
import 'auth.dart';
import 'share_store.dart';
import 'web_ui_v2.dart';

class LanServerStatus {
  const LanServerStatus({
    required this.isRunning,
    this.host,
    this.port,
    this.url,
  });

  final bool isRunning;
  final String? host;
  final int? port;
  final String? url;
}

class LanHttpServerController {
  LanHttpServerController({
    LanlockRepository? repo,
    ServerPasswordStore? passwordStore,
  })  : _repo = repo ?? LanlockRepository(),
        _passwordStore = passwordStore ?? const ServerPasswordStore();

  final LanlockRepository _repo;
  final ServerPasswordStore _passwordStore;
  final SessionManager _sessions = SessionManager();
  final LanShareStore shareStore = LanShareStore();

  HttpServer? _server;
  String? _host;
  int? _port;

  final _statusStream = StreamController<LanServerStatus>.broadcast();

  Stream<LanServerStatus> get statusStream => _statusStream.stream;

  LanServerStatus get status => LanServerStatus(
        isRunning: _server != null,
        host: _host,
        port: _port,
        url: (_host != null && _port != null) ? 'http://$_host:$_port' : null,
      );

  Future<bool> hasServerPassword() => _passwordStore.hasPassword();

  Future<void> setServerPassword(String password) => _passwordStore.setPassword(password);

  Future<bool> verifyServerPassword(String password) => _passwordStore.verifyPassword(password);

  Future<LanServerStatus> start({
    int port = 8080,
  }) async {
    if (_server != null) return status;

    final hasPw = await _passwordStore.hasPassword();
    if (!hasPw) throw StateError('Set a server password first');

    _host = await _discoverLanIpv4() ?? '127.0.0.1';

    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_cors())
        .addHandler(_router().call);

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );

    _port = _server!.port;
    _emit();
    return status;
  }

  Future<void> stop() async {
    final srv = _server;
    if (srv == null) return;
    await srv.close(force: true);
    _server = null;
    _host = null;
    _port = null;
    _emit();
  }

  void dispose() {
    _statusStream.close();
  }

  void _emit() {
    if (!_statusStream.isClosed) _statusStream.add(status);
  }

  Middleware _cors() {
    return (innerHandler) {
      return (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final resp = await innerHandler(request);
        return resp.change(headers: _corsHeaders);
      };
    };
  }

  static const Map<String, String> _corsHeaders = <String, String>{
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'access-control-allow-headers': 'content-type, authorization, x-filename, cookie',
    'cache-control': 'no-store',
  };

  Router _router() {
    final r = Router();

    // Web UI.
    r.get('/', (Request req) {
      return Response.ok(
        lanlockWebIndexHtmlV2,
        headers: {
          'content-type': 'text/html; charset=utf-8',
          ..._corsHeaders,
        },
      );
    });

    r.get('/health', (Request _) => Response.ok('ok'));

    // Auth endpoints.
    r.get('/api/me', (Request req) {
      final token = _getSessionToken(req);
      if (token == null || !_sessions.isValid(token)) return Response(401);
      return _json({'ok': true});
    });

    r.post('/api/login', (Request req) async {
      final body = await _readJson(req);
      final password = (body['password'] ?? '').toString();

      final ok = await _passwordStore.verifyPassword(password);
      if (!ok) return _json({'error': 'invalid'}, status: 401);

      final token = _sessions.createSession();
      return _json(
        {'ok': true},
        headers: {
          'set-cookie': 'lanlock_session=$token; HttpOnly; SameSite=Strict; Path=/',
        },
      );
    });

    r.post('/api/logout', (Request req) async {
      final token = _getSessionToken(req);
      if (token != null) _sessions.revoke(token);
      return _json(
        {'ok': true},
        headers: {
          'set-cookie': 'lanlock_session=; Max-Age=0; HttpOnly; SameSite=Strict; Path=/',
        },
      );
    });

    // Read-only API.
    r.get('/api/profiles', (Request req) async {
      if (!_isAuthed(req)) return Response(401);
      final q = req.url.queryParameters['q'] ?? '';
      final profiles = await _repo.searchProfiles(q);
      return _json({
        'profiles': [
          for (final p in profiles) {'id': p.id, 'name': p.name}
        ],
      });
    });

    r.get('/api/profile/<id|[0-9]+>/password', (Request req, String id) async {
      if (!_isAuthed(req)) return Response(401);
      final profileId = int.parse(id);
      final pw = await _repo.decryptProfilePassword(profileId);
      return _json({'password': pw});
    });

    r.get('/api/profile/<id|[0-9]+>/meta_keys', (Request req, String id) async {
      if (!_isAuthed(req)) return Response(401);
      final profileId = int.parse(id);
      final keys = await _repo.listMetaKeys(profileId);
      return _json({
        'keys': [
          for (final k in keys) {'id': k.id, 'keyName': k.keyName}
        ],
      });
    });

    r.get('/api/meta/<id|[0-9]+>/value', (Request req, String id) async {
      if (!_isAuthed(req)) return Response(401);
      final metaKeyId = int.parse(id);
      final value = await _repo.decryptMetaKeyValue(metaKeyId);
      return _json({'value': value});
    });

    // LAN share hub (text + files; same session auth).
    r.get('/api/share/list', (Request req) {
      if (!_isAuthed(req)) return Response(401);
      return _json({
        'items': [for (final i in shareStore.list()) i.toJsonSummary()],
      });
    });

    r.post('/api/share/text', (Request req) async {
      if (!_isAuthed(req)) return Response(401);
      final body = await _readJson(req);
      final text = (body['text'] ?? '').toString();
      if (text.isEmpty) return _json({'error': 'empty'}, status: 400);
      try {
        final item = shareStore.addText(text);
        return _json({'ok': true, 'id': item.id});
      } catch (e) {
        return _json({'error': e.toString()}, status: 400);
      }
    });

    r.post('/api/share/file', (Request req) async {
      if (!_isAuthed(req)) return Response(401);
      final name = req.headers['x-filename'] ?? 'upload.bin';
      final bytes = await _readRequestBytes(req);
      if (bytes.isEmpty) return _json({'error': 'empty body'}, status: 400);
      try {
        final item = await shareStore.addFile(bytes, name);
        return _json({'ok': true, 'id': item.id});
      } catch (e) {
        return _json({'error': e.toString()}, status: 400);
      }
    });

    r.get('/api/share/item/<id>/text', (Request req, String id) {
      if (!_isAuthed(req)) return Response(401);
      final item = shareStore.get(id);
      if (item == null || item.kind != ShareKind.text) {
        return _json({'error': 'not found'}, status: 404);
      }
      return _json({'text': item.text ?? ''});
    });

    r.get('/api/share/item/<id>/file', (Request req, String id) async {
      if (!_isAuthed(req)) return Response(401);
      final item = shareStore.get(id);
      if (item == null || item.kind != ShareKind.file || item.filePath == null) {
        return Response.notFound('not found');
      }
      final f = File(item.filePath!);
      if (!await f.exists()) return Response.notFound('missing file');
      final bytes = await f.readAsBytes();
      return Response.ok(
        bytes,
        headers: {
          'content-type': 'application/octet-stream',
          'content-disposition': 'attachment; filename="${item.label}"',
          ..._corsHeaders,
        },
      );
    });

    r.delete('/api/share/item/<id>', (Request req, String id) {
      if (!_isAuthed(req)) return Response(401);
      final ok = shareStore.remove(id);
      return _json({'ok': ok});
    });

    return r;
  }

  bool _isAuthed(Request req) {
    final token = _getSessionToken(req);
    return token != null && _sessions.isValid(token);
  }

  static String? _getSessionToken(Request req) {
    final cookie = req.headers['cookie'];
    if (cookie == null) return null;
    for (final part in cookie.split(';')) {
      final p = part.trim();
      if (p.startsWith('lanlock_session=')) {
        return p.substring('lanlock_session='.length);
      }
    }
    return null;
  }

  static Response _json(Object body, {int status = 200, Map<String, String>? headers}) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        ...?headers,
        ..._corsHeaders,
      },
    );
  }

  static Future<Uint8List> _readRequestBytes(Request req) async {
    final b = BytesBuilder(copy: false);
    await for (final chunk in req.read()) {
      b.add(chunk);
    }
    return b.takeBytes();
  }

  static Future<Map<String, dynamic>> _readJson(Request req) async {
    final raw = await req.readAsString();
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  static Future<String?> _discoverLanIpv4() async {
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}

