import 'package:flutter/material.dart';

import '../../lanlock_repository.dart';

class EditMetaKeyDialog extends StatefulWidget {
  const EditMetaKeyDialog({
    super.key,
    required this.repo,
    required this.profileId,
    this.metaKeyId,
    required this.initialKeyName,
    required this.initialValue,
    this.title,
  });

  final LanlockRepository repo;
  final int profileId;
  final int? metaKeyId;
  final String initialKeyName;
  final String initialValue;
  final String? title;

  @override
  State<EditMetaKeyDialog> createState() => _EditMetaKeyDialogState();
}

class _EditMetaKeyDialogState extends State<EditMetaKeyDialog> {
  late final TextEditingController _keyController;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.initialKeyName);
    _valueController = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogTitle = widget.title ??
        (widget.metaKeyId == null ? 'Add Metadata Key' : 'Edit Metadata Key');

    return AlertDialog(
      backgroundColor: const Color(0xFF0F1324),
      title: Text(dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meta key name:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keyController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Meta value:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valueController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final newKeyName = _keyController.text.trim();
            if (newKeyName.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Meta key name cannot be empty')),
                );
              }
              return;
            }
            final newValue = _valueController.text;

            try {
              if (widget.metaKeyId != null) {
                await widget.repo.updateMetaKeyAndValue(
                  metaKeyId: widget.metaKeyId!,
                  newKeyName: newKeyName,
                  newValue: newValue,
                );
              } else {
                await widget.repo.upsertMetaKeyValue(
                  profileId: widget.profileId,
                  keyName: newKeyName,
                  value: newValue,
                );
              }
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent.withOpacity(0.95),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

