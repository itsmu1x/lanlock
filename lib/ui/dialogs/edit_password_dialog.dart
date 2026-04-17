import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../lanlock_repository.dart';
import '../../password_generator.dart';
import '../lanlock_toast.dart';

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
  final _customPasswordController = TextEditingController();

  bool _useGeneratedPassword = true;

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

  @override
  void dispose() {
    _customPasswordController.dispose();
    super.dispose();
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

  String get _activePassword =>
      _useGeneratedPassword ? _generatedPassword : _customPasswordController.text;

  TextStyle _sectionTitle(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall!.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        );
  }

  TextStyle _hint(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall!.copyWith(
          color: Colors.white54,
          height: 1.35,
        );
  }

  InputDecoration _fieldDecoration({String? label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white60),
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
    );
  }

  Future<void> _copyPassword() async {
    final pw = _activePassword;
    if (pw.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: pw));
    if (context.mounted) {
      showLanlockToast(context, 'Password copied', kind: LanlockToastKind.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedPassword =
        _showPassword ? _activePassword : '*' * _activePassword.length;
    final maxH = MediaQuery.sizeOf(context).height * 0.82;

    return AlertDialog(
      backgroundColor: const Color(0xFF0F1324),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      title: Row(
        children: [
          Icon(
            Icons.lock_reset_rounded,
            color: Colors.deepPurpleAccent.withOpacity(0.95),
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Edit password',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxH),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Secret', style: _sectionTitle(context)),
              const SizedBox(height: 4),
              Text(
                'Generate a strong password or type your own.',
                style: _hint(context),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Generate'),
                      selected: _useGeneratedPassword,
                      onSelected: (v) {
                        if (v) {
                          setState(() {
                            _useGeneratedPassword = true;
                            _showPassword = false;
                            _regeneratePassword();
                          });
                        }
                      },
                      showCheckmark: false,
                      selectedColor: const Color(0xFF1D2340),
                      backgroundColor: const Color(0xFF13192B),
                      side: BorderSide(
                        color: _useGeneratedPassword
                            ? Colors.deepPurpleAccent.withOpacity(0.45)
                            : Colors.white.withOpacity(0.12),
                      ),
                      labelStyle: TextStyle(
                        color: _useGeneratedPassword ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Custom'),
                      selected: !_useGeneratedPassword,
                      onSelected: (v) {
                        if (v) {
                          setState(() {
                            _useGeneratedPassword = false;
                            _showPassword = false;
                          });
                        }
                      },
                      showCheckmark: false,
                      selectedColor: const Color(0xFF1D2340),
                      backgroundColor: const Color(0xFF13192B),
                      side: BorderSide(
                        color: !_useGeneratedPassword
                            ? Colors.deepPurpleAccent.withOpacity(0.45)
                            : Colors.white.withOpacity(0.12),
                      ),
                      labelStyle: TextStyle(
                        color: !_useGeneratedPassword ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_useGeneratedPassword) ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _TogChip(
                      label: 'A–Z / a–z',
                      selected: _useAlphabets,
                      onTap: () {
                        setState(() {
                          _useAlphabets = !_useAlphabets;
                          _regeneratePassword();
                        });
                      },
                    ),
                    _TogChip(
                      label: '0–9',
                      selected: _useNumerics,
                      onTap: () {
                        setState(() {
                          _useNumerics = !_useNumerics;
                          _regeneratePassword();
                        });
                      },
                    ),
                    _TogChip(
                      label: 'Symbols',
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
                const SizedBox(height: 14),
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
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '$_length',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        tooltip: _showPassword ? 'Hide' : 'Show',
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        color: Colors.white70,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        tooltip: 'Copy',
                        onPressed: _copyPassword,
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        color: Colors.white70,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(_regeneratePassword),
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
                    label: const Text('Regenerate', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _customPasswordController,
                  obscureText: !_showPassword,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  decoration: _fieldDecoration(
                    hint: 'Type or paste your password',
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Copy',
                    onPressed: _copyPassword,
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final pw = _activePassword;
            if (pw.isEmpty) {
              if (context.mounted) {
                showLanlockToast(
                  context,
                  'Password cannot be empty.',
                  kind: LanlockToastKind.error,
                );
              }
              return;
            }
            try {
              await widget.repo.updateProfilePassword(
                profileId: widget.profileId,
                newPassword: pw,
              );
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              if (context.mounted) {
                showLanlockToast(context, 'Failed: $e', kind: LanlockToastKind.error);
              }
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent.withOpacity(0.95),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            color: selected
                ? Colors.deepPurpleAccent.withOpacity(0.95)
                : Colors.white.withOpacity(0.12),
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
