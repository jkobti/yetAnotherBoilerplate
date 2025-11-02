import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/auth/auth_repository.dart';
import '../core/auth/token_storage.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  String _status = 'unknown';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _me;

  Future<void> _checkHealth() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.I.health();
      setState(() {
        _status = data['status']?.toString() ?? 'unknown';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAuthAndMe() async {
    final repo = AuthRepository(ApiClient.I, TokenStorage());
    await repo.init();
    final me = await repo.me();
    if (mounted) setState(() => _me = me);
  }

  @override
  void initState() {
    super.initState();
    _loadAuthAndMe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Portal')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backend health: $_status'),
                const SizedBox(height: 12),
                if (_error != null)
                  Text('Error: $_error',
                      style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      onPressed: _loading ? null : _checkHealth,
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_me == null) ...[
                  const Text('Not signed in. Admin features require login.'),
                ] else if (!(_me!['is_staff'] == true)) ...[
                  const Text('You are signed in but not an admin.'),
                ] else ...[
                  Text('Welcome, ${_me!['email']} (admin)'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
