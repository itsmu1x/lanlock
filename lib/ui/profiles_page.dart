import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import '../lanlock_repository.dart';
import '../lan_server/server.dart';
import 'dialogs/add_profile_dialog.dart';
import 'lanlock_toast.dart';
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

  List<HomeLayoutRow> _homeLayout = const [];
  List<ProfileSummary> _searchHits = const [];
  String _query = '';
  bool _isLoading = false;

  Timer? _debounce;

  bool get _searching => _query.trim().isNotEmpty;

  int get _homeProfileCount =>
      _homeLayout.where((r) => r.kind == HomeItemKind.profile).length;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final q = (query ?? _query).trim();
      if (q.isNotEmpty) {
        final list = await _repo.searchProfiles(q);
        if (mounted) setState(() => _searchHits = list);
      } else {
        final list = await _repo.loadHomeLayout();
        if (mounted) setState(() => _homeLayout = list);
      }
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

  Future<void> _onReorderHome(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final next = List<HomeLayoutRow>.from(_homeLayout);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    setState(() => _homeLayout = next);
    try {
      await _repo.reorderHomeLayout(next.map((e) => e.homeItemId).toList());
    } catch (_) {
      if (mounted) {
        await _refresh();
        showLanlockToast(
          context,
          'Could not save new order.',
          kind: LanlockToastKind.error,
        );
      }
    }
  }

  Future<void> _promptAddSpacer() async {
    final controller = TextEditingController(text: 'New section');
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1324),
        title: const Text(
          'New section',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Section title',
            labelStyle: const TextStyle(color: Colors.white70),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.9),
              ),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.95),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    // Dispose after the dialog route is gone so the TextField is not still attached.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (!mounted || title == null || title.isEmpty) return;
    try {
      await _repo.createSpacer(title: title);
      await _refresh();
    } catch (e) {
      if (mounted) {
        showLanlockToast(
          context,
          'Could not add section: $e',
          kind: LanlockToastKind.error,
        );
      }
    }
  }

  Future<void> _editSpacer(HomeLayoutRow row) async {
    final sid = row.spacerId;
    if (sid == null) return;
    final controller = TextEditingController(text: row.spacerTitle ?? '');
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1324),
        title: const Text(
          'Rename section',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Title',
            labelStyle: const TextStyle(color: Colors.white70),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.9),
              ),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.95),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (!mounted || title == null || title.isEmpty) return;
    try {
      await _repo.updateSpacerTitle(spacerId: sid, title: title);
      await _refresh();
    } catch (e) {
      if (mounted) {
        showLanlockToast(
          context,
          'Could not rename: $e',
          kind: LanlockToastKind.error,
        );
      }
    }
  }

  Future<void> _deleteSpacerConfirm(HomeLayoutRow row) async {
    final sid = row.spacerId;
    if (sid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1324),
        title: const Text(
          'Remove section?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Only the section header is removed. Password entries stay in your vault '
          'and keep their order.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteSpacer(sid);
      await _refresh();
    } catch (e) {
      if (mounted) {
        showLanlockToast(
          context,
          'Could not remove section: $e',
          kind: LanlockToastKind.error,
        );
      }
    }
  }

  void _openProfileFromRow(HomeLayoutRow row) {
    final id = row.profileId;
    final name = row.profileName;
    if (id == null || name == null) return;
    _openProfile(ProfileSummary(id: id, name: name));
  }

  Future<void> _openProfile(ProfileSummary p) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileDetailPage(profileId: p.id, profileName: p.name),
      ),
    );
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    if (result == true) {
      showLanlockToast(
        context,
        'Profile deleted',
        kind: LanlockToastKind.success,
      );
    }
  }

  /// Wider tiles = shorter rows (see [_gridChildAspect]); more columns on big screens.
  int _crossAxisCount(double width) {
    if (width >= 1000) return 5;
    if (width >= 760) return 4;
    if (width >= 480) return 3;
    return 2;
  }

  static const double _gridChildAspect = 4.2;
  static const double _gridMainGap = 4;
  static const double _gridCrossGap = 4;

  @override
  Widget build(BuildContext context) {
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
                              Text(
                                'LanLock',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.95,
                                      ),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (_isLoading &&
                            (_searching
                                ? _searchHits.isNotEmpty
                                : _homeLayout.isNotEmpty))
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (_isLoading &&
                            (_searching
                                ? _searchHits.isNotEmpty
                                : _homeLayout.isNotEmpty))
                          const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'LAN Server',
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder<void>(
                                transitionDuration: const Duration(
                                  milliseconds: 130,
                                ),
                                reverseTransitionDuration: const Duration(
                                  milliseconds: 110,
                                ),
                                pageBuilder: (_, animation, __) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: ServerPanelPage(
                                        controller: _serverController,
                                      ),
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
              const SizedBox(height: 8),
              Expanded(
                child:
                    _isLoading &&
                        (_searching ? _searchHits.isEmpty : _homeLayout.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final filtered = _searching;
                          final cross = _crossAxisCount(constraints.maxWidth);
                          if (filtered && _searchHits.isEmpty) {
                            return RefreshIndicator(
                              onRefresh: () => _refresh(),
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  8,
                                  18,
                                  120,
                                ),
                                children: [_EmptyProfilesState(hasQuery: true)],
                              ),
                            );
                          }
                          if (!filtered && _homeLayout.isEmpty) {
                            return RefreshIndicator(
                              onRefresh: () => _refresh(),
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  8,
                                  18,
                                  120,
                                ),
                                children: [
                                  _EmptyProfilesState(hasQuery: false),
                                ],
                              ),
                            );
                          }
                          if (filtered) {
                            return RefreshIndicator(
                              onRefresh: () => _refresh(),
                              child: GridView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  2,
                                  12,
                                  120,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cross,
                                      mainAxisSpacing: _gridMainGap,
                                      crossAxisSpacing: _gridCrossGap,
                                      childAspectRatio: _gridChildAspect,
                                    ),
                                itemCount: _searchHits.length,
                                itemBuilder: (context, i) {
                                  final p = _searchHits[i];
                                  return ProfileCard(
                                    key: ValueKey(p.id),
                                    title: p.name,
                                    dense: true,
                                    showReorderHandle: false,
                                    onTap: () => _openProfile(p),
                                  );
                                },
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: () => _refresh(),
                                  child: ReorderableListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      2,
                                      20,
                                      8,
                                    ),
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    buildDefaultDragHandles: false,
                                    itemCount: _homeLayout.length,
                                    onReorder: _onReorderHome,
                                    itemBuilder: (context, index) {
                                      final row = _homeLayout[index];
                                      if (row.kind == HomeItemKind.spacer) {
                                        return _SpacerRow(
                                          key: ValueKey(
                                            'home_${row.homeItemId}',
                                          ),
                                          reorderIndex: index,
                                          title: row.spacerTitle ?? '',
                                          onEdit: () => _editSpacer(row),
                                          onDelete: () =>
                                              _deleteSpacerConfirm(row),
                                        );
                                      }
                                      return Row(
                                        key: ValueKey('home_${row.homeItemId}'),
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          ReorderableDragStartListener(
                                            index: index,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8,
                                                bottom: 4,
                                              ),
                                              child: SizedBox(
                                                width: 44,
                                                height: 48,
                                                child: Center(
                                                  child: Icon(
                                                    Icons
                                                        .drag_indicator_rounded,
                                                    size: 24,
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.38,
                                                        ),
                                                    semanticLabel:
                                                        'Drag to reorder',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: ProfileCard(
                                                title: row.profileName ?? '',
                                                dense: true,
                                                showReorderHandle: false,
                                                onTap: () =>
                                                    _openProfileFromRow(row),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                              if (_homeProfileCount == 0 &&
                                  _homeLayout.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    0,
                                    18,
                                    100,
                                  ),
                                  child: Text(
                                    'No password entries yet — tap Add to create one. '
                                    'Sections are optional headers; drag items to organize.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.white54,
                                          height: 1.35,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Builder(
        builder: (fabContext) {
          return FloatingActionButton(
            tooltip: 'Add',
            backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.92),
            foregroundColor: Colors.white,
            child: const Icon(Icons.add_rounded),
            onPressed: () async {
              final button = fabContext.findRenderObject() as RenderBox?;
              final overlayBox =
                  Overlay.maybeOf(fabContext)?.context.findRenderObject()
                      as RenderBox?;
              if (button == null ||
                  overlayBox == null ||
                  !button.hasSize ||
                  !overlayBox.hasSize) {
                return;
              }
              final position = RelativeRect.fromRect(
                Rect.fromPoints(
                  button.localToGlobal(Offset.zero, ancestor: overlayBox),
                  button.localToGlobal(
                    button.size.bottomRight(Offset.zero),
                    ancestor: overlayBox,
                  ),
                ),
                Offset.zero & overlayBox.size,
              );
              final selected = await showMenu<String>(
                context: fabContext,
                position: position,
                color: const Color(0xFF151828),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
                elevation: 12,
                items: const [
                  PopupMenuItem<String>(
                    value: 'password',
                    child: _AddMenuRow(
                      icon: Icons.vpn_key_rounded,
                      label: 'Add password',
                      iconColor: Color(0xFFD0BCFF),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'spacer',
                    child: _AddMenuRow(
                      icon: Icons.view_week_rounded,
                      label: 'Add section',
                      iconColor: Colors.white70,
                    ),
                  ),
                ],
              );
              if (!mounted) return;
              if (selected == 'password') {
                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => AddProfileDialog(repo: _repo),
                );
                if (created == true) await _refresh();
              } else if (selected == 'spacer') {
                await _promptAddSpacer();
              }
            },
          );
        },
      ),
    );
  }

  Future<bool> _authenticateForBackup() async {
    try {
      if (kIsWeb ||
          (defaultTargetPlatform != TargetPlatform.android &&
              defaultTargetPlatform != TargetPlatform.iOS)) {
        if (!mounted) return false;
        showLanlockToast(
          context,
          'Biometric/PIN auth for backup is available on Android/iOS only.',
          kind: LanlockToastKind.info,
        );
        return false;
      }

      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        if (!mounted) return false;
        showLanlockToast(
          context,
          'Device authentication is not available.',
          kind: LanlockToastKind.info,
        );
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access backup export/import',
        biometricOnly: false,
      );

      if (!authenticated && mounted) {
        showLanlockToast(
          context,
          'Authentication canceled.',
          kind: LanlockToastKind.info,
        );
      }
      return authenticated;
    } on MissingPluginException {
      if (!mounted) return false;
      showLanlockToast(
        context,
        'Auth plugin not ready. Run "flutter pub get" and fully restart the app.',
        kind: LanlockToastKind.info,
      );
      return false;
    } on PlatformException catch (e) {
      final msg = (e.message ?? e.code).toLowerCase();
      if (msg.contains('unable to establish connection on channel')) {
        if (!mounted) return false;
        showLanlockToast(
          context,
          'Auth channel unavailable. Please fully restart app after "flutter pub get".',
          kind: LanlockToastKind.info,
        );
        return false;
      }
      if (!mounted) return false;
      showLanlockToast(
        context,
        'Authentication failed: ${e.message ?? e.code}',
        kind: LanlockToastKind.error,
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      showLanlockToast(
        context,
        'Authentication failed.',
        kind: LanlockToastKind.error,
      );
      return false;
    }
  }

  Future<void> _openExportDialog() async {
    try {
      final payload = await _repo.exportBackupPayload();
      final json = const JsonEncoder.withIndent('  ').convert(payload);
      final bytes = Uint8List.fromList(utf8.encode(json));
      final now = DateTime.now();
      final name =
          'lanlock_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save LanLock backup',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (path == null) return;
      if (!mounted) return;
      showLanlockToast(
        context,
        'Backup file saved: $path',
        kind: LanlockToastKind.success,
        duration: const Duration(milliseconds: 4000),
      );
    } catch (e) {
      if (!mounted) return;
      showLanlockToast(
        context,
        'Export failed: $e',
        kind: LanlockToastKind.error,
      );
    }
  }

  Future<void> _openImportDialog() async {
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
            content: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white70),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a backup .json file to import.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.deepPurpleAccent,
                    value: replaceExisting,
                    onChanged: (v) => setStateDialog(() => replaceExisting = v),
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
      final file = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select LanLock backup file',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: false,
      );
      if (file == null || file.files.isEmpty) return;
      final path = file.files.single.path;
      if (path == null || path.isEmpty) {
        throw ArgumentError('Could not read selected file path.');
      }
      final raw = await File(path).readAsString();
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
      showLanlockToast(
        context,
        'Import done: ${stats['imported']} imported, ${stats['skipped']} skipped, ${stats['failed']} failed.',
        kind: LanlockToastKind.success,
        duration: const Duration(milliseconds: 4000),
      );
    } catch (e) {
      if (!mounted) return;
      showLanlockToast(
        context,
        'Import failed: $e',
        kind: LanlockToastKind.error,
      );
    }
  }
}

class _AddMenuRow extends StatelessWidget {
  const _AddMenuRow({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SpacerRow extends StatelessWidget {
  const _SpacerRow({
    super.key,
    required this.reorderIndex,
    required this.title,
    required this.onEdit,
    required this.onDelete,
  });

  final int reorderIndex;
  final String title;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final label = title.trim().isEmpty ? 'Section' : title.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
      child: Material(
        color: Colors.deepPurpleAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ReorderableDragStartListener(
              index: reorderIndex,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 24,
                      color: Colors.white.withValues(alpha: 0.38),
                      semanticLabel: 'Drag section to reorder',
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFD0BCFF),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.85,
                  fontSize: 11.5,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Rename section',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: Colors.white.withValues(alpha: 0.55),
              ),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Remove section',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
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
              'Tap + to add a password or section.',
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
          hintText: 'Search passwords…',
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
