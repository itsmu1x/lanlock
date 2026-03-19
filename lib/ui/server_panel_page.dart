import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../lan_server/server.dart';

class ServerPanelPage extends StatefulWidget {
  const ServerPanelPage({super.key, required this.controller});

  final LanHttpServerController controller;

  @override
  State<ServerPanelPage> createState() => _ServerPanelPageState();
}

class _ServerPanelPageState extends State<ServerPanelPage> {
  final _setPwController = TextEditingController();

  bool _hasPw = false;
  bool _busy = false;

  LanServerStatus _status = const LanServerStatus(isRunning: false);

  @override
  void initState() {
    super.initState();
    _status = widget.controller.status;
    widget.controller.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
    });
    _load();
  }

  Future<void> _load() async {
    final has = await widget.controller.hasServerPassword();
    if (!mounted) return;
    setState(() => _hasPw = has);
  }

  @override
  void dispose() {
    _setPwController.dispose();
    super.dispose();
  }

  Future<void> _setPassword() async {
    final pw = _setPwController.text;
    if (pw.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use at least 6 characters')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.controller.setServerPassword(pw);
      _setPwController.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server password set')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleServer(bool on) async {
    if (on) {
      if (!_hasPw) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set a server password first')),
        );
        return;
      }
      setState(() => _busy = true);
      try {
        await widget.controller.start(port: 8080);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start: $e')),
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
                          ? 'Web access is protected by the same server password.'
                          : 'Set a password, then switch ON.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    if (url != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        url,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                            border: Border.all(color: Colors.white.withOpacity(0.10)),
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
                title: 'Server password',
                subtitle: 'Required for web login',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password is stored securely (PBKDF2 hash).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _setPwController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _hasPw ? 'Set new password' : 'Set server password',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _setPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent.withOpacity(0.95),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(_hasPw ? 'Update Password' : 'Set Password'),
                      ),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ),
            ],
          ),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
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

