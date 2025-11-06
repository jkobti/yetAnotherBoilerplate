import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/app_scaffold.dart';
import '../core/auth/auth_state.dart';

class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authStateProvider).valueOrNull;
    if (me != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/app');
      });
    }
    return AppScaffold(
      title: 'Boilerplate',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'A minimal, functional starter',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Modern UI, auth, and push – ready to build on.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Log in'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go('/signup'),
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
