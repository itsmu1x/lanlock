import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../lanlock_repository.dart';
import '../../password_generator.dart';

class EditPasswordDialog extends StatefulWidget {
  const EditPasswordDialog({
    super.key,
    required this.repo,
    required this.profileId,
  });

  final LanlockRepository repo;
  final int profileId;

  @override
  State<EditPasswordDialog> createState() => _EditPasswordDialogState();
}

class _EditPasswordDialogState extends State<EditPasswordDialog> {
  bool _useAlphabets = true;
  bool _useNumerics = true;
  bool _useSpecial = false;
  int _length = 48;

  bool _showPassword = false;

  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _regeneratePassword();
  }

  void _regeneratePassword() {
    _generatedPassword = PasswordGenerator.generate(
      PasswordOptions(
        useAlphabets: _useAlphabets,
        useNumerics: _useNumerics,
        useSpecialCharacters: _useSpecial,
        length: _length,
      ),
    );
  }

  Future<void> _copy() async {
    final pw = _generatedPassword;
    if (pw.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: pw));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedPassword = _showPassword ? _generatedPassword : '*' * _generatedPassword.length;

    return AlertDialog(
      backgroundColor: const Color(0xFF0F1324),
      title: const Text('Edit Password'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _TogChip(
                  label: 'Alphabets',
                  selected: _useAlphabets,
                  onTap: () {
                    setState(() {
                      _useAlphabets = !_useAlphabets;
                      _regeneratePassword();
                    });
                  },
                ),
                _TogChip(
                  label: 'Numerics',
                  selected: _useNumerics,
                  onTap: () {
                    setState(() {
                      _useNumerics = !_useNumerics;
                      _regeneratePassword();
                    });
                  },
                ),
                _TogChip(
                  label: 'Special',
                  selected: _useSpecial,
                  onTap: () {
                    setState(() {
                      _useSpecial = !_useSpecial;
                      _regeneratePassword();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.deepPurpleAccent,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.deepPurpleAccent,
                    ),
                    child: Slider(
                      min: 12,
                      max: 128,
                      divisions: 116,
                      value: _length.toDouble(),
                      onChanged: (v) {
                        setState(() {
                          _length = v.round();
                          _regeneratePassword();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  child: Text(
                    '$_length',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      displayedPassword,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    tooltip: _showPassword ? 'Hide' : 'Show',
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    ),
                    color: Colors.white70,
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: _copy,
                    icon: const Icon(Icons.copy_rounded),
                    color: Colors.white70,
                  ),
                ],
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
            try {
              await widget.repo.updateProfilePassword(
                profileId: widget.profileId,
                newPassword: _generatedPassword,
              );
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

class _TogChip extends StatelessWidget {
  const _TogChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? Colors.deepPurpleAccent.withOpacity(0.20) : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: selected ? Colors.deepPurpleAccent.withOpacity(0.95) : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

