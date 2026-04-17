import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../lan_server/auth.dart';
import '../lanlock_crypto.dart';
import 'lanlock_toast.dart';
import 'onboarding_prefs.dart';
import 'profiles_page.dart';

enum _LockPhase {
  loading,
  biometricWall,
  welcomeOnboarding,
  createMasterPassword,
  unlock,
}

class MasterLockPage extends StatefulWidget {
  const MasterLockPage({super.key});

  @override
  State<MasterLockPage> createState() => _MasterLockPageState();
}

class _MasterLockPageState extends State<MasterLockPage> {
  final ServerPasswordStore _masterStore = const ServerPasswordStore();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  _LockPhase _phase = _LockPhase.loading;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    LanlockCrypto.clearSessionKey();
    if (!mounted) return;
    setState(() => _phase = _LockPhase.loading);
    await _runStartupBiometricThenContinue();
  }

  Future<void> _runStartupBiometricThenContinue() async {
    final vaultExists = await _masterStore.hasPassword();
    if (!vaultExists) {
      if (!mounted) return;
      await _continueAfterBiometric();
      return;
    }

    final ok = await _authenticateAppEntry();
    if (!ok) {
      if (mounted) setState(() => _phase = _LockPhase.biometricWall);
      return;
    }
    if (!mounted) return;
    await _continueAfterBiometric();
  }

  Future<void> _continueAfterBiometric() async {
    final restored = await LanlockCrypto.tryRestoreSessionKey();
    if (restored) {
      if (!mounted) return;
      _goToApp();
      return;
    }

    final has = await _masterStore.hasPassword();
    final ack = await OnboardingPrefs.hasAcknowledgedLocalOnlyRisk();
    if (!mounted) return;
    setState(() {
      if (has) {
        _phase = _LockPhase.unlock;
      } else if (!ack) {
        _phase = _LockPhase.welcomeOnboarding;
      } else {
        _phase = _LockPhase.createMasterPassword;
      }
    });
  }

  Future<void> _retryBiometricFromWall() async {
    if (!mounted) return;
    setState(() => _phase = _LockPhase.loading);
    final ok = await _authenticateAppEntry();
    if (!ok) {
      if (mounted) setState(() => _phase = _LockPhase.biometricWall);
      return;
    }
    if (!mounted) return;
    await _continueAfterBiometric();
  }

  Future<bool> _authenticateAppEntry() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return true;
    }

    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) return true;

      final biometrics = await _localAuth.getAvailableBiometrics();
      final biometricOnly = biometrics.isNotEmpty;

      return _localAuth.authenticate(
        localizedReason: 'Authenticate to open LanLock',
        biometricOnly: biometricOnly,
      );
    } on MissingPluginException {
      return true;
    } on PlatformException catch (e) {
      final msg = (e.message ?? e.code).toLowerCase();
      if (msg.contains('unable to establish connection on channel')) {
        return true;
      }
      if (mounted) {
        showLanlockToast(
          context,
          'Authentication error: ${e.message ?? e.code}',
          kind: LanlockToastKind.error,
        );
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onWelcomeContinue() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1324),
        icon: Icon(
          Icons.storage_rounded,
          color: Colors.amberAccent.withValues(alpha: 0.95),
          size: 40,
        ),
        title: Text(
          'Heads up: your vault is only here',
          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LanLock keeps secrets on this device — not on our servers (there aren’t any). '
                'Uninstalling the app, clearing app storage, or wiping the phone removes your vault '
                'unless you’ve exported a backup from the app.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.9),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You’re in charge. That’s the trade-off for being the #1 password vault for people who want offline, LAN-friendly control.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.95),
              foregroundColor: Colors.white,
            ),
            child: const Text('I understand — continue'),
          ),
        ],
      ),
    );

    if (accepted == true && mounted) {
      await OnboardingPrefs.setAcknowledgedLocalOnlyRisk();
      setState(() => _phase = _LockPhase.createMasterPassword);
    }
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

    setState(() => _phase = _LockPhase.loading);
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
      if (mounted) {
        setState(() => _phase = _LockPhase.createMasterPassword);
      }
    }
  }

  Future<void> _unlock() async {
    final pw = _passwordController.text;
    if (pw.isEmpty) {
      _showSnack('Enter your master password.', kind: LanlockToastKind.info);
      return;
    }
    setState(() => _phase = _LockPhase.loading);
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
      if (mounted) setState(() => _phase = _LockPhase.unlock);
    }
  }

  void _goToApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfilesPage()),
    );
  }

  void _showSnack(String message, {LanlockToastKind kind = LanlockToastKind.error}) {
    if (!mounted) return;
    showLanlockToast(context, message, kind: kind);
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
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: _buildPhaseContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent(BuildContext context) {
    switch (_phase) {
      case _LockPhase.loading:
        return const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        );
      case _LockPhase.biometricWall:
        return _BiometricWall(onAuthenticate: _retryBiometricFromWall);
      case _LockPhase.welcomeOnboarding:
        return _OnboardingWelcome(onContinue: _onWelcomeContinue);
      case _LockPhase.createMasterPassword:
        return _masterPasswordForm(context, isUnlock: false);
      case _LockPhase.unlock:
        return _masterPasswordForm(context, isUnlock: true);
    }
  }

  Widget _masterPasswordForm(BuildContext context, {required bool isUnlock}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isUnlock ? 'Unlock LanLock' : 'Create your master password',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          isUnlock
              ? 'Enter your master password — the saved key on this device is missing or expired.'
              : 'This one password encrypts your vault. Choose something strong; we cannot reset it for you.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: !_showPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: isUnlock ? 'Master password' : 'New master password',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
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
        if (!isUnlock) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _confirmController,
            obscureText: !_showPassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Confirm password',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isUnlock ? _unlock : _setMasterPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.95),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(isUnlock ? 'Unlock' : 'Set password & enter vault'),
          ),
        ),
      ],
    );
  }
}

class _OnboardingWelcome extends StatelessWidget {
  const _OnboardingWelcome({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220, maxHeight: 120),
            child: Image.asset(
              'lib/assets/clean_logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Welcome to LanLock v2',
          style: t.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'The #1 password vault for people who want their secrets offline, on their network, under their lock.',
          style: t.titleSmall?.copyWith(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.92),
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'No accounts. No cloud by default. Biometrics and LAN sharing when you want them — you hold the keys.',
          style: t.bodyMedium?.copyWith(
            color: Colors.white70,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continue'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.95),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _BiometricWall extends StatelessWidget {
  const _BiometricWall({required this.onAuthenticate});

  final VoidCallback onAuthenticate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.fingerprint_rounded,
          size: 56,
          color: Colors.deepPurpleAccent.withValues(alpha: 0.95),
        ),
        const SizedBox(height: 14),
        Text(
          "Confirm it's you",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Use your fingerprint or device screen lock to open LanLock.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.35,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: onAuthenticate,
          icon: const Icon(Icons.fingerprint_rounded),
          label: const Text('Authenticate'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.95),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}
