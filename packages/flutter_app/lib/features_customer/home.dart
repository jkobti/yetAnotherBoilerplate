import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/api_client.dart';
import '../core/auth/auth_repository.dart';
import '../core/auth/token_storage.dart';
import '../core/push/push_service.dart';
import '../core/widgets/app_scaffold.dart';
import '../core/auth/auth_state.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
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
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadAuthAndMe() async {
    final repo = AuthRepository(ApiClient.I, TokenStorage());
    await repo.init();
    final me = await repo.me();
    if (mounted) setState(() => _me = me);
  }

  Future<void> _logout() async {
    await ref.read(authStateProvider.notifier).signOut();
    if (mounted) setState(() => _me = null);
  }

  @override
  void initState() {
    super.initState();
    _loadAuthAndMe();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Customer App',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Backend health: $_status'),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                PrimaryButton(
                  onPressed: _loading ? null : _checkHealth,
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Check health'),
                ),
                const SizedBox(height: 24),
                if (_me == null) ...[
                  const Text('You are not signed in.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Go to Login'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: const Text('Create an account'),
                  ),
                ] else ...[
                  Text('Signed in as: ${_me!['email']}'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _logout,
                    child: const Text('Logout'),
                  ),
                  const SizedBox(height: 24),
                  if (PushService.isEnabled)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Push notifications demo'),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => PushService.initializeAndRegister(context),
                              child: const Text('Enable push'),
                            ),
                            const SizedBox(height: 8),
                            const Text('Incoming messages will appear as a Snackbar while this tab is active.'),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
