import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_state.dart';

class AuthGuard extends ConsumerWidget {
  final Widget child;
  final bool requireStaff;
  final String redirectTo;

  const AuthGuard({
    super.key,
    required this.child,
    this.requireStaff = false,
    this.redirectTo = '/login',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(redirectTo);
        });
        return const SizedBox.shrink();
      },
      data: (me) {
        final isLoggedIn = me != null;
        final isStaff = (me?['is_staff'] == true);
        final allowed = isLoggedIn && (!requireStaff || isStaff);
        if (!allowed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(redirectTo);
          });
          return const SizedBox.shrink();
        }
        return child;
      },
    );
  }
}
