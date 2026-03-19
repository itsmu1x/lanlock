import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../lanlock_repository.dart';
import '../../password_generator.dart';

class AddProfileDialog extends StatefulWidget {
  const AddProfileDialog({super.key, required this.repo});

  final LanlockRepository repo;

  @override
  State<AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<AddProfileDialog> {
  final _nameController = TextEditingController();
  final _customPasswordController = TextEditingController();

  bool _useGeneratedPassword = true;

  bool _useAlphabets = true;
  bool _useNumerics = true;
  bool _useSpecial = false;
  int _length = 48;

  bool _showPassword = false;

  String _generatedPassword = '';

  final List<_MetaRowDraft> _metaRows = [_MetaRowDraft()];

  @override
  void initState() {
    super.initState();
    _regeneratePassword();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customPasswordController.dispose();
    for (final row in _metaRows) {
      row.dispose();
    }
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

  String get _activePassword => _useGeneratedPassword ? _generatedPassword : _customPasswordController.text;

  Future<void> _copyPassword() async {
    final pw = _activePassword;
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
    final displayedPassword = _showPassword ? _activePassword : '*' * _activePassword.length;

    return AlertDialog(
      backgroundColor: const Color(0xFF0F1324),
      title: const Text('Add Password Profile'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile name:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                  ),
                  hintText: 'e.g. gmail/main or github/personal',
                  hintStyle: const TextStyle(color: Colors.white54),
                ),
              ),

              const SizedBox(height: 16),

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

              Text(
                'Password:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 10),

              if (_useGeneratedPassword) ...[
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

                const SizedBox(height: 16),

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

                const SizedBox(height: 10),

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
                        onPressed: _copyPassword,
                        icon: const Icon(Icons.copy_rounded),
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _regeneratePassword();
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    label: const Text('Regenerate', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _customPasswordController,
                  obscureText: !_showPassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      color: Colors.white70,
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Copy',
                    onPressed: _copyPassword,
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                  ),
                ),
              ],

              const SizedBox(height: 18),

              Row(
                children: [
                  const Text(
                    'Metadata keys:',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _metaRows.add(_MetaRowDraft())),
                    icon: const Icon(Icons.add_rounded, color: Colors.white70),
                    label: const Text('Add', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              ListView.builder(
                itemCount: _metaRows.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, idx) {
                  final row = _metaRows[idx];
                  return _MetaRowEditor(
                    index: idx,
                    canRemove: _metaRows.length > 1,
                    onRemove: () {
                      setState(() {
                        if (_metaRows.length <= 1) return;
                        row.dispose();
                        _metaRows.removeAt(idx);
                      });
                    },
                    keyController: row.keyController,
                    valueController: row.valueController,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final profileName = _nameController.text.trim();
            if (profileName.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile name is required')),
                );
              }
              return;
            }

            final password = _activePassword;
            if (password.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password is required')),
                );
              }
              return;
            }

            final metadata = <String, String>{};
            for (final row in _metaRows) {
              final k = row.keyController.text.trim();
              if (k.isEmpty) continue;
              metadata[k] = row.valueController.text;
            }

            try {
              await widget.repo.createProfile(
                name: profileName,
                password: password,
                metadata: metadata,
              );
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to add profile: $e')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent.withOpacity(0.95),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
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
          border: Border.all(color: selected ? Colors.deepPurpleAccent.withOpacity(0.95) : Colors.white.withOpacity(0.12)),
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

class _MetaRowDraft {
  _MetaRowDraft()
      : keyController = TextEditingController(),
        valueController = TextEditingController();

  final TextEditingController keyController;
  final TextEditingController valueController;

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

class _MetaRowEditor extends StatelessWidget {
  const _MetaRowEditor({
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.keyController,
    required this.valueController,
  });

  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final TextEditingController keyController;
  final TextEditingController valueController;

  InputDecoration _decoration(BuildContext context, {required String label, required String hint, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white60),
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: Colors.white54, size: 18),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.deepPurpleAccent.withOpacity(0.9)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 420;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Metadata ${index + 1}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: canRemove ? 'Remove' : 'At least one required',
                    onPressed: canRemove ? onRemove : null,
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: keyController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration(
                          context,
                          label: 'Key',
                          hint: 'e.g. email',
                          icon: Icons.label_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: valueController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        decoration: _decoration(
                          context,
                          label: 'Value',
                          hint: 'e.g. me@example.com',
                          icon: Icons.text_fields_rounded,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    TextField(
                      controller: keyController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration(
                        context,
                        label: 'Key',
                        hint: 'e.g. email',
                        icon: Icons.label_rounded,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: valueController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: _decoration(
                        context,
                        label: 'Value',
                        hint: 'e.g. me@example.com',
                        icon: Icons.text_fields_rounded,
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

