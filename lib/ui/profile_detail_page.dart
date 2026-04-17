import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lanlock_repository.dart';
import 'lanlock_toast.dart';
import 'dialogs/edit_meta_key_dialog.dart';
import 'dialogs/edit_password_dialog.dart';
import 'widgets/meta_key_row.dart';

class ProfileDetailPage extends StatefulWidget {
  const ProfileDetailPage({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  final int profileId;
  final String profileName;

  @override
  State<ProfileDetailPage> createState() => _ProfileDetailPageState();
}

class _ProfileDetailPageState extends State<ProfileDetailPage> {
  final LanlockRepository _repo = LanlockRepository();

  late String _profileTitle;

  List<MetaKeySummary> _metaKeys = const [];
  bool _isLoadingMetaKeys = false;

  @override
  void initState() {
    super.initState();
    _profileTitle = widget.profileName;
    _loadMetaKeys();
  }

  Future<void> _loadMetaKeys() async {
    setState(() => _isLoadingMetaKeys = true);
    try {
      final list = await _repo.listMetaKeys(widget.profileId);
      if (mounted) setState(() => _metaKeys = list);
    } finally {
      if (mounted) setState(() => _isLoadingMetaKeys = false);
    }
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showLanlockToast(context, 'Copied', kind: LanlockToastKind.success);
    }
  }

  Future<void> _showSecret(String title, String secret) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1324),
        title: Text(title),
        content: SelectableText(secret, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _copyText(secret);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent.withOpacity(0.95),
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Future<void> _viewPassword() async {
    final password = await _repo.decryptProfilePassword(widget.profileId);
    await _showSecret('Password', password);
  }

  Future<void> _copyPassword() async {
    final password = await _repo.decryptProfilePassword(widget.profileId);
    await _copyText(password);
  }

  Future<void> _editPassword() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => EditPasswordDialog(
        repo: _repo,
        profileId: widget.profileId,
      ),
    );
    if (updated == true && mounted) {
      showLanlockToast(context, 'Password updated', kind: LanlockToastKind.success);
    }
  }

  Future<void> _renameProfile() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameProfileDialog(initialName: _profileTitle),
    );
    if (newName == null || !mounted) return;
    final trimmed = newName.trim();
    if (trimmed == _profileTitle) return;
    try {
      await _repo.updateProfileName(profileId: widget.profileId, newName: trimmed);
      if (!mounted) return;
      setState(() => _profileTitle = trimmed);
      showLanlockToast(context, 'Renamed', kind: LanlockToastKind.success);
    } catch (e) {
      if (!mounted) return;
      showLanlockToast(context, 'Rename failed: $e', kind: LanlockToastKind.error);
    }
  }

  Future<void> _viewMetaKey(MetaKeySummary metaKey) async {
    final value = await _repo.decryptMetaKeyValue(metaKey.id);
    await _showSecret(metaKey.keyName, value);
  }

  Future<void> _copyMetaKey(MetaKeySummary metaKey) async {
    final value = await _repo.decryptMetaKeyValue(metaKey.id);
    await _copyText(value);
  }

  Future<void> _deleteMetaKey(MetaKeySummary metaKey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1324),
        title: const Text(
          'Delete field?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove "${metaKey.keyName}" from this entry? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.deleteMetaKey(metaKey.id);
      if (!mounted) return;
      await _loadMetaKeys();
      showLanlockToast(context, 'Metadata removed', kind: LanlockToastKind.success);
    } catch (e) {
      if (!mounted) return;
      showLanlockToast(context, 'Delete failed: $e', kind: LanlockToastKind.error);
    }
  }

  Future<void> _editMetaKey(MetaKeySummary metaKey) async {
    final value = await _repo.decryptMetaKeyValue(metaKey.id);
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => EditMetaKeyDialog(
        repo: _repo,
        profileId: widget.profileId,
        metaKeyId: metaKey.id,
        initialKeyName: metaKey.keyName,
        initialValue: value,
        title: 'Edit Metadata',
      ),
    );
    if (updated == true && mounted) {
      await _loadMetaKeys();
      showLanlockToast(context, 'Metadata updated', kind: LanlockToastKind.success);
    }
  }

  Future<void> _addMetaKey() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => EditMetaKeyDialog(
        repo: _repo,
        profileId: widget.profileId,
        initialKeyName: '',
        initialValue: '',
        title: 'Add Metadata Key',
      ),
    );
    if (created == true && mounted) {
      await _loadMetaKeys();
    }
  }

  Future<void> _deleteProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1324),
        title: const Text(
          'Delete profile?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This removes "$_profileTitle" and all its metadata. This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repo.deleteProfile(widget.profileId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showLanlockToast(context, 'Delete failed: $e', kind: LanlockToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A12),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      _profileTitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rename',
                    icon: const Icon(Icons.edit_rounded, color: Colors.white70),
                    onPressed: _renameProfile,
                  ),
                  IconButton(
                    tooltip: 'Delete profile',
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    onPressed: _deleteProfile,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_rounded, color: Colors.deepPurpleAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Password',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'view', child: Text('View')),
                        PopupMenuItem(value: 'copy', child: Text('Copy')),
                      ],
                      onSelected: (value) async {
                        switch (value) {
                          case 'edit':
                            await _editPassword();
                            break;
                          case 'view':
                            await _viewPassword();
                            break;
                          case 'copy':
                            await _copyPassword();
                            break;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Text(
                    'Metadata Keys',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addMetaKey,
                    icon: const Icon(Icons.add_rounded, color: Colors.white70),
                    label: const Text('Add', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoadingMetaKeys
                  ? const Center(child: CircularProgressIndicator())
                  : _metaKeys.isEmpty
                      ? Center(
                          child: Text(
                            'No metadata yet. Add one.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                          children: [
                            for (final metaKey in _metaKeys)
                              MetaKeyRow(
                                keyName: metaKey.keyName,
                                onEdit: () => _editMetaKey(metaKey),
                                onView: () => _viewMetaKey(metaKey),
                                onCopy: () => _copyMetaKey(metaKey),
                                onDelete: () => _deleteMetaKey(metaKey),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns [TextEditingController] so it is disposed after the route is torn down
/// (avoids `_dependents.isEmpty` when disposing synchronously after [showDialog]).
class _RenameProfileDialog extends StatefulWidget {
  const _RenameProfileDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameProfileDialog> createState() => _RenameProfileDialogState();
}

class _RenameProfileDialogState extends State<_RenameProfileDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F1324),
      title: const Text('Rename', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Name',
          labelStyle: const TextStyle(color: Colors.white60),
          hintText: 'Unique label for this password',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.deepPurpleAccent.withOpacity(0.85)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final t = _controller.text.trim();
            if (t.isEmpty) {
              showLanlockToast(
                context,
                'Name cannot be empty',
                kind: LanlockToastKind.error,
              );
              return;
            }
            Navigator.pop(context, t);
          },
          style: FilledButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

