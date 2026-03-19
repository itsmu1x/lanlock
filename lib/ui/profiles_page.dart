import 'dart:async';

import 'package:flutter/material.dart';

import '../lanlock_repository.dart';
import '../lan_server/server.dart';
import 'dialogs/add_profile_dialog.dart';
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

  List<ProfileSummary> _profiles = const [];
  String _query = '';
  bool _isLoading = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final list = await _repo.searchProfiles(query ?? _query);
      if (mounted) setState(() => _profiles = list);
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

  @override
  Widget build(BuildContext context) {
    final grouped = _groupProfiles(_profiles);

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
                          child: Text(
                            'Profiles',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'LAN Server',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServerPanelPage(controller: _serverController),
                              ),
                            );
                          },
                          icon: const Icon(Icons.wifi_tethering_rounded, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _SearchBar(
                      initialQuery: _query,
                      onQueryChanged: (value) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 250), () {
                          _query = value;
                          _refresh(query: value);
                        });
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _query.trim().isEmpty
                            ? 'Tap a box to manage metadata + password'
                            : 'Results for "${_query.trim()}"',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => _refresh(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
                          children: [
                            if (_profiles.isEmpty)
                              _EmptyProfilesState(hasQuery: _query.trim().isNotEmpty)
                            else ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Tip: Use profile names like "gmail/main" or "github/personal" to organize folders.',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: Colors.white54,
                                      ),
                                ),
                              ),
                              for (final entry in grouped.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, bottom: 10),
                                  child: Text(
                                    entry.key,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                  ),
                                ),
                                ...entry.value.map((p) {
                                  final parsed = _splitProfilePath(p.name);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ProfileCard(
                                      name: parsed.leaf,
                                      subtitle: parsed.subPath,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProfileDetailPage(
                                              profileId: p.id,
                                              profileName: p.name,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (_) => AddProfileDialog(repo: _repo),
          );
          if (created == true) {
            await _refresh();
          }
        },
        backgroundColor: Colors.deepPurpleAccent.withOpacity(0.92),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
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
              'Tap the Add button to create one.',
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

Map<String, List<ProfileSummary>> _groupProfiles(List<ProfileSummary> profiles) {
  final sorted = [...profiles];
  sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final grouped = <String, List<ProfileSummary>>{};
  for (final p in sorted) {
    final folder = _topFolder(p.name);
    grouped.putIfAbsent(folder, () => <ProfileSummary>[]).add(p);
  }
  return grouped;
}

String _topFolder(String name) {
  final normalized = name.trim();
  final idx = normalized.indexOf('/');
  if (idx <= 0) return 'General';
  return normalized.substring(0, idx);
}

_PathInfo _splitProfilePath(String fullName) {
  final normalized = fullName.trim();
  if (normalized.isEmpty) return const _PathInfo(leaf: 'Unnamed', subPath: null);
  final parts = normalized.split('/').where((p) => p.trim().isNotEmpty).toList();
  if (parts.isEmpty) return const _PathInfo(leaf: 'Unnamed', subPath: null);
  if (parts.length == 1) return _PathInfo(leaf: parts.first, subPath: null);
  return _PathInfo(
    leaf: parts.last,
    subPath: parts.sublist(0, parts.length - 1).join('/'),
  );
}

class _PathInfo {
  const _PathInfo({required this.leaf, required this.subPath});

  final String leaf;
  final String? subPath;
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.initialQuery,
    required this.onQueryChanged,
  });

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
          hintText: 'Search profiles...',
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
            borderSide: BorderSide(color: Colors.deepPurpleAccent.withOpacity(0.9)),
          ),
        ),
      ),
    );
  }
}

