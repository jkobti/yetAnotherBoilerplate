import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/api_client.dart';
// Removed direct repository/token imports; relying on global authStateProvider.
import '../core/push/push_service.dart';
import '../core/widgets/app_scaffold.dart';
import '../core/auth/auth_state.dart';
import '../core/feature_flags/feature_flags_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _status = 'unknown';
  bool _loading = false;
  String? _error;

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

  Future<void> _logout() async {
    await ref.read(authStateProvider.notifier).signOut();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final meData = authState.asData?.value;
    final demoFeatureEnabled =
        ref.watch(featureFlagSelectorProvider('demo_feature'));
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
                if (authState.isLoading) ...[
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(),
                ] else if (meData == null) ...[
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
                  Text('Signed in as: ${meData['email']}'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _logout,
                    child: const Text('Logout'),
                  ),
                  const SizedBox(height: 24),
                  // Instructional title (always visible, independent of flag-gated card)
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'please add flag feature_flag to revel magic',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (demoFeatureEnabled)
                    Builder(
                      builder: (context) {
                        final cs = Theme.of(context).colorScheme;
                        final cardBg = cs.brightness == Brightness.dark
                            ? cs.surfaceContainerHighest.withOpacity(0.6)
                            : cs.surfaceContainerHighest;
                        final headingStyle = Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold);
                        final bodyStyle =
                            Theme.of(context).textTheme.bodyMedium;
                        return Card(
                          color: cardBg,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Demo Feature', style: headingStyle),
                                const SizedBox(height: 10),
                                Text(
                                  'This component is controlled by the "demo_feature" flag. Toggle it from the admin portal to show/hide this card and press refresh to re-fetch flags.',
                                  style: bodyStyle,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => ref
                                          .read(featureFlagsProvider.notifier)
                                          .refresh(),
                                      child: const Text('Refresh flags'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
                              onPressed: () =>
                                  PushService.initializeAndRegister(context),
                              child: const Text('Enable push'),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                                'Incoming messages will appear as a Snackbar while this tab is active.'),
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
