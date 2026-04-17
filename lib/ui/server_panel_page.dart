import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../lan_server/share_store.dart';
import '../lan_server/server.dart';
import 'lanlock_toast.dart';

class ServerPanelPage extends StatefulWidget {
  const ServerPanelPage({super.key, required this.controller});

  final LanHttpServerController controller;

  @override
  State<ServerPanelPage> createState() => _ServerPanelPageState();
}

class _ServerPanelPageState extends State<ServerPanelPage> {
  final _shareTextController = TextEditingController();

  bool _hasPw = false;
  bool _busy = false;
  bool _shareBusy = false;

  LanServerStatus _status = const LanServerStatus(isRunning: false);

  @override
  void initState() {
    super.initState();
    _status = widget.controller.status;
    widget.controller.shareStore.addListener(_onShareChanged);
    widget.controller.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
    });
    _load();
  }

  void _onShareChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final has = await widget.controller.hasServerPassword();
    if (!mounted) return;
    setState(() => _hasPw = has);
  }

  @override
  void dispose() {
    widget.controller.shareStore.removeListener(_onShareChanged);
    _shareTextController.dispose();
    super.dispose();
  }

  Future<void> _sendShareText() async {
    final t = _shareTextController.text.trim();
    if (t.isEmpty) {
      showLanlockToast(context, 'Enter some text', kind: LanlockToastKind.info);
      return;
    }
    setState(() => _shareBusy = true);
    try {
      widget.controller.shareStore.addText(t);
      _shareTextController.clear();
    } catch (e) {
      if (mounted) {
        showLanlockToast(
          context,
          'Could not add: $e',
          kind: LanlockToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _pickShareFile() async {
    setState(() => _shareBusy = true);
    try {
      final r = await FilePicker.platform.pickFiles(withData: true);
      if (r == null || r.files.isEmpty) return;
      final f = r.files.single;
      var bytes = f.bytes;
      if (bytes == null && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null) {
        if (mounted) {
          showLanlockToast(
            context,
            'Could not read that file',
            kind: LanlockToastKind.error,
          );
        }
        return;
      }
      final name = f.name.isNotEmpty ? f.name : 'file.bin';
      await widget.controller.shareStore.addFile(bytes, name);
    } catch (e) {
      if (mounted) {
        showLanlockToast(
          context,
          'Could not add file: $e',
          kind: LanlockToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _copyShareText(ShareItem item) async {
    final t = item.text ?? '';
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;
    showLanlockToast(
      context,
      'Copied to clipboard',
      kind: LanlockToastKind.success,
    );
  }

  Future<void> _openShareFile(ShareItem item) async {
    final p = item.filePath;
    if (p == null) return;
    final r = await OpenFile.open(p);
    if (!mounted) return;
    if (r.type != ResultType.done) {
      showLanlockToast(context, r.message, kind: LanlockToastKind.error);
    }
  }

  void _removeShareItem(String id) {
    widget.controller.shareStore.remove(id);
  }

  Future<void> _toggleServer(bool on) async {
    if (on) {
      if (!_hasPw) {
        showLanlockToast(
          context,
          'Set a master password from the LanLock lock screen first.',
          kind: LanlockToastKind.info,
        );
        return;
      }
      setState(() => _busy = true);
      try {
        await widget.controller.start(port: kLanHttpPort);
      } catch (e) {
        if (mounted) {
          showLanlockToast(
            context,
            'Failed to start: $e',
            kind: LanlockToastKind.error,
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else {
      setState(() => _busy = true);
      try {
        await widget.controller.stop();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _status.url;
    return Scaffold(
      backgroundColor: const Color(0xFF070A12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070A12),
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('LAN Server'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF070A12), Color(0xFF070A12)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              _GlassCard(
                title: 'Status',
                subtitle: _status.isRunning ? 'Running' : 'Stopped (default)',
                trailing: Switch(
                  value: _status.isRunning,
                  onChanged: _busy ? null : _toggleServer,
                  activeColor: Colors.deepPurpleAccent,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _status.isRunning
                          ? 'Web access is protected by your master password.'
                          : _hasPw
                          ? 'Switch ON to allow web access on your LAN.'
                          : 'Set a master password from the LanLock lock screen, then switch ON.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    if (url != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        url,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: QrImageView(
                            data: url,
                            size: 220,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _GlassCard(
                title: 'LAN Share',
                subtitle: _status.isRunning
                    ? 'Text & files for this session (phone ↔ browser)'
                    : 'Start the server to sync with other devices',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shared items use the same login as the web UI. Up to 80 items; files up to ~48 MB.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _shareTextController,
                      minLines: 2,
                      maxLines: 5,
                      enabled: !_shareBusy,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Paste or type text to share…',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _shareBusy ? null : _sendShareText,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigoAccent.withOpacity(
                                0.85,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Send text'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _shareBusy ? null : _pickShareFile,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.25),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Add file'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Inbox',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final items = widget.controller.shareStore.list();
                        if (items.isEmpty) {
                          return Text(
                            'Nothing yet. Other devices can send after logging in on the web page.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white54),
                          );
                        }
                        return Column(
                          children: [
                            for (final item in items)
                              _ShareInboxTile(
                                item: item,
                                onCopyText: item.kind == ShareKind.text
                                    ? () => _copyShareText(item)
                                    : null,
                                onOpenFile: item.kind == ShareKind.file
                                    ? () => _openShareFile(item)
                                    : null,
                                onDelete: () => _removeShareItem(item.id),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _GlassCard(
                title: 'Notes',
                subtitle: 'LAN safety',
                child: Text(
                  'Only run this on trusted networks. The web UI requires login and uses session cookies.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareInboxTile extends StatelessWidget {
  const _ShareInboxTile({
    required this.item,
    required this.onDelete,
    this.onCopyText,
    this.onOpenFile,
  });

  final ShareItem item;
  final VoidCallback onDelete;
  final VoidCallback? onCopyText;
  final VoidCallback? onOpenFile;

  static String _formatSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool _looksLikeImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    final path = item.filePath;
    final imagePreview =
        item.kind == ShareKind.file &&
        path != null &&
        _looksLikeImage(item.label) &&
        File(path).existsSync();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.kind == ShareKind.text
                      ? Icons.notes_rounded
                      : Icons.insert_drive_file_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.kind == ShareKind.text ? 'Text' : item.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatSize(item.sizeBytes),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white54),
                ),
              ],
            ),
            if (item.kind == ShareKind.text &&
                (item.text ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.text!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
            if (imagePreview)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(path),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (onCopyText != null)
                  TextButton.icon(
                    onPressed: onCopyText,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.lightBlueAccent,
                    ),
                  ),
                if (onOpenFile != null)
                  TextButton.icon(
                    onPressed: onOpenFile,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.lightGreenAccent,
                    ),
                  ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent.shade100,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
