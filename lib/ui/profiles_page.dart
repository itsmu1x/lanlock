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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            final crossAxisCount = width >= 780
                                ? 4
                                : width >= 520
                                    ? 3
                                    : width >= 360
                                        ? 2
                                        : 1;
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.62,
                              ),
                              itemCount: _profiles.length,
                              itemBuilder: (context, index) {
                                final p = _profiles[index];
                                return ProfileCard(
                                  name: p.name,
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
                                );
                              },
                            );
                          },
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

