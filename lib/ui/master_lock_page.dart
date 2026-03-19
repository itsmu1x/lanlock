import 'package:flutter/material.dart';

import '../lan_server/auth.dart';
import '../lanlock_crypto.dart';
import 'profiles_page.dart';

class MasterLockPage extends StatefulWidget {
  const MasterLockPage({super.key});

  @override
  State<MasterLockPage> createState() => _MasterLockPageState();
}

class _MasterLockPageState extends State<MasterLockPage> {
  final ServerPasswordStore _masterStore = const ServerPasswordStore();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _busy = true;
  bool _hasMasterPassword = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    LanlockCrypto.clearSessionKey();
    final restored = await LanlockCrypto.tryRestoreSessionKey();
    if (restored) {
      if (!mounted) return;
      _goToApp();
      return;
    }

    final has = await _masterStore.hasPassword();
    if (!mounted) return;
    setState(() {
      _hasMasterPassword = has;
      _busy = false;
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _setMasterPassword() async {
    final pw = _passwordController.text;
    final confirm = _confirmController.text;
    if (pw.trim().length < 8) {
      _showSnack('Use at least 8 characters.');
      return;
    }
    if (pw != confirm) {
      _showSnack('Passwords do not match.');
      return;
    }

    setState(() => _busy = true);
    try {
      await _masterStore.setPassword(pw);
      final key = await _masterStore.deriveEncryptionKey(pw);
      LanlockCrypto.setSessionKey(key);
      await LanlockCrypto.persistSessionKey(key);
      if (!mounted) return;
      _goToApp();
    } catch (e) {
      _showSnack('Failed to set password: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlock() async {
    final pw = _passwordController.text;
    if (pw.isEmpty) {
      _showSnack('Enter your master password.');
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await _masterStore.verifyPassword(pw);
      if (!ok) {
        _showSnack('Wrong master password.');
        return;
      }
      final key = await _masterStore.deriveEncryptionKey(pw);
      LanlockCrypto.setSessionKey(key);
      await LanlockCrypto.persistSessionKey(key);
      if (!mounted) return;
      _goToApp();
    } catch (e) {
      _showSnack('Unlock failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goToApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfilesPage()),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A12),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasMasterPassword ? 'Unlock LanLock' : 'Set Master Password',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hasMasterPassword
                                ? 'Enter your master password to unlock because saved key is missing.'
                                : 'You must set a master password before using the app.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: _hasMasterPassword ? 'Master password' : 'New master password',
                              labelStyle: const TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                              ),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _showPassword = !_showPassword),
                                icon: Icon(
                                  _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          if (!_hasMasterPassword) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _confirmController,
                              obscureText: !_showPassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Confirm password',
                                labelStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.06),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _busy ? null : (_hasMasterPassword ? _unlock : _setMasterPassword),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurpleAccent.withOpacity(0.95),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(_hasMasterPassword ? 'Unlock' : 'Set Password'),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
