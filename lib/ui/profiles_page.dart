import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../lanlock_repository.dart';
import '../lan_server/server.dart';
import 'dialogs/add_profile_dialog.dart';
import 'profile_detail_page.dart';
import 'server_panel_page.dart';
import 'widgets/profile_card.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  final LanlockRepository _repo = LanlockRepository();
  final LanHttpServerController _serverController = LanHttpServerController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  List<ProfileSummary> _profiles = const [];
  String _query = '';
  bool _isLoading = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.searchProfiles(query ?? _query);
      if (mounted) setState(() => _profiles = list);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupProfiles(_profiles);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF070A12), Color(0xFF070A12)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white.withValues(alpha: 0.06),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Image.asset(
                                  'lib/assets/lanlock_logo.png',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'LanLock',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'LAN Server',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServerPanelPage(
                                  controller: _serverController,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.wifi_tethering_rounded,
                            color: Colors.white70,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Backup',
                          color: const Color(0xFF121828),
                          onSelected: (value) async {
                            final allowed = await _authenticateForBackup();
                            if (!allowed) return;
                            if (value == 'export') {
                              await _openExportDialog();
                              return;
                            }
                            if (value == 'import') {
                              await _openImportDialog();
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'export',
                              child: Text(
                                'Export backup',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'import',
                              child: Text(
                                'Import backup',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          icon: const Icon(
                            Icons.import_export_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SearchBar(
                      initialQuery: _query,
                      onQueryChanged: (value) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 250),
                          () {
                            _query = value;
                            _refresh(query: value);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _query.trim().isEmpty
                            ? 'Tap a box to manage metadata + password'
                            : 'Results for "${_query.trim()}"',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => _refresh(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
                          children: [
                            if (_profiles.isEmpty)
                              _EmptyProfilesState(
                                hasQuery: _query.trim().isNotEmpty,
                              )
                            else ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Tip: Use profile names like "gmail/main" or "github/personal" to organize folders.',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(color: Colors.white54),
                                ),
                              ),
                              for (final entry in grouped.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    bottom: 10,
                                  ),
                                  child: Text(
                                    entry.key,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                  ),
                                ),
                                ...entry.value.map((p) {
                                  final parsed = _splitProfilePath(p.name);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ProfileCard(
                                      name: parsed.leaf,
                                      subtitle: parsed.subPath,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProfileDetailPage(
                                              profileId: p.id,
                                              profileName: p.name,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (_) => AddProfileDialog(repo: _repo),
          );
          if (created == true) {
            await _refresh();
          }
        },
        backgroundColor: Colors.deepPurpleAccent.withOpacity(0.92),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }

  Future<bool> _authenticateForBackup() async {
    try {
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.android &&
              defaultTargetPlatform != TargetPlatform.iOS)) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric/PIN auth for backup is available on Android/iOS only.',
            ),
          ),
        );
        return false;
      }

      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device authentication is not available.'),
          ),
        );
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access backup export/import',
        biometricOnly: false,
      );

      if (!authenticated && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication canceled.')),
        );
      }
      return authenticated;
    } on MissingPluginException {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Auth plugin not ready. Run "flutter pub get" and fully restart the app.',
          ),
        ),
      );
      return false;
    } on PlatformException catch (e) {
      final msg = (e.message ?? e.code).toLowerCase();
      if (msg.contains('unable to establish connection on channel')) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Auth channel unavailable. Please fully restart app after "flutter pub get".',
            ),
          ),
        );
        return false;
      }
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication failed: ${e.message ?? e.code}'),
        ),
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Authentication failed.')));
      return false;
    }
  }

  Future<void> _openExportDialog() async {
    try {
      final payload = await _repo.exportBackupPayload();
      final json = const JsonEncoder.withIndent('  ').convert(payload);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
              brightness: Brightness.dark,
              surface: const Color(0xFF0F1324),
              onSurface: Colors.white,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
            ),
            textTheme: Theme.of(ctx).textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
            listTileTheme: const ListTileThemeData(
              textColor: Colors.white,
              iconColor: Colors.white70,
            ),
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
            ),
            dialogTheme: const DialogThemeData(
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              contentTextStyle: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          child: AlertDialog(
            surfaceTintColor: Colors.transparent,
            backgroundColor: const Color(0xFF0F1324),
            title: const Text(
              'Export Backup',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width > 700
                  ? 620
                  : MediaQuery.of(ctx).size.width * 0.88,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white70),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Copy this JSON and store it in a safe place.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          json,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: json));
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Backup JSON copied')),
                  );
                },
                child: const Text('Copy JSON'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent.withOpacity(0.92),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _openImportDialog() async {
    final jsonController = TextEditingController();
    var replaceExisting = false;

    final action = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
              brightness: Brightness.dark,
              surface: const Color(0xFF0F1324),
              onSurface: Colors.white,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
            ),
            textTheme: Theme.of(ctx).textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
            listTileTheme: const ListTileThemeData(
              textColor: Colors.white,
              iconColor: Colors.white70,
            ),
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
            ),
            dialogTheme: const DialogThemeData(
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              contentTextStyle: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          child: AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            scrollable: true,
            surfaceTintColor: Colors.transparent,
            backgroundColor: const Color(0xFF0F1324),
            title: const Text(
              'Import Backup',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width > 700
                  ? 620
                  : MediaQuery.of(ctx).size.width * 0.88,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white70),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paste backup JSON here.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: jsonController,
                      minLines: 8,
                      maxLines: 12,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '{"format":"lanlock-backup-v1", ...}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.deepPurpleAccent.withOpacity(0.85),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.deepPurpleAccent,
                      value: replaceExisting,
                      onChanged: (v) =>
                          setStateDialog(() => replaceExisting = v),
                      title: const Text(
                        'Replace existing profiles with same name',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Off = skip duplicates. On = update password/metadata.',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent.withOpacity(0.92),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Import'),
              ),
            ],
          ),
        ),
      ),
    );

    if (action != true) {
      return;
    }

    try {
      final raw = jsonController.text.trim();
      if (raw.isEmpty) {
        throw ArgumentError('Backup JSON is empty.');
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw ArgumentError('Backup JSON root must be an object.');
      }
      final stats = await _repo.importBackupPayload(
        decoded,
        replaceExisting: replaceExisting,
      );
      if (!mounted) return;
      await _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import done: ${stats['imported']} imported, ${stats['skipped']} skipped, ${stats['failed']} failed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      // Intentionally not disposing here to avoid a race with dialog close
      // animations where TextField may still read the controller briefly.
    }
  }
}

class _EmptyProfilesState extends StatelessWidget {
  const _EmptyProfilesState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final title = hasQuery ? 'No matches found' : 'No passwords yet';
    final subtitle = hasQuery
        ? 'Try another search phrase or clear the search.'
        : 'Create your first profile to start storing passwords securely.';

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.deepPurpleAccent.withOpacity(0.35),
                  Colors.indigoAccent.withOpacity(0.24),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
            ),
            child: Icon(
              hasQuery ? Icons.search_off_rounded : Icons.lock_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          if (!hasQuery) ...[
            const SizedBox(height: 12),
            Text(
              'Tap the Add button to create one.',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

Map<String, List<ProfileSummary>> _groupProfiles(
  List<ProfileSummary> profiles,
) {
  final sorted = [...profiles];
  sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final grouped = <String, List<ProfileSummary>>{};
  for (final p in sorted) {
    final folder = _topFolder(p.name);
    grouped.putIfAbsent(folder, () => <ProfileSummary>[]).add(p);
  }
  return grouped;
}

String _topFolder(String name) {
  final normalized = name.trim();
  final idx = normalized.indexOf('/');
  if (idx <= 0) return 'General';
  return normalized.substring(0, idx);
}

_PathInfo _splitProfilePath(String fullName) {
  final normalized = fullName.trim();
  if (normalized.isEmpty)
    return const _PathInfo(leaf: 'Unnamed', subPath: null);
  final parts = normalized
      .split('/')
      .where((p) => p.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) return const _PathInfo(leaf: 'Unnamed', subPath: null);
  if (parts.length == 1) return _PathInfo(leaf: parts.first, subPath: null);
  return _PathInfo(
    leaf: parts.last,
    subPath: parts.sublist(0, parts.length - 1).join('/'),
  );
}

class _PathInfo {
  const _PathInfo({required this.leaf, required this.subPath});

  final String leaf;
  final String? subPath;
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.initialQuery, required this.onQueryChanged});

  final String initialQuery;
  final ValueChanged<String> onQueryChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant _SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _controller.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TextField(
        controller: _controller,
        onChanged: widget.onQueryChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search profiles...',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white60),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.deepPurpleAccent.withOpacity(0.9),
            ),
          ),
        ),
      ),
    );
  }
}
