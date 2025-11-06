import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme_controller.dart';
import '../../core/push/push_service.dart';

class AppScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final bool isAdmin;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark =
        themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // Primary nav
          if (_isWide(context)) ..._navActions(context) else _navMenu(context),
          if (PushService.isEnabled)
            IconButton(
              tooltip: 'Enable notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => PushService.initializeAndRegister(context),
            ),
          IconButton(
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: body,
    );
  }

  bool _isWide(BuildContext context) {
    return MediaQuery.of(context).size.width >= 720;
  }

  List<Widget> _navActions(BuildContext context) {
    if (isAdmin) {
      return [
        TextButton(
          onPressed: () => context.go('/'),
          child: const Text('Dashboard'),
        ),
        TextButton(
          onPressed: () => context.go('/users'),
          child: const Text('Users'),
        ),
      ];
    }
    return [
      TextButton(
        onPressed: () => context.go('/'),
        child: const Text('Home'),
      ),
      TextButton(
        onPressed: () => context.go('/login'),
        child: const Text('Login'),
      ),
      TextButton(
        onPressed: () => context.go('/signup'),
        child: const Text('Sign up'),
      ),
    ];
  }

  Widget _navMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      onSelected: (value) {
        context.go(value);
      },
      itemBuilder: (context) {
        if (isAdmin) {
          return const [
            PopupMenuItem(value: '/', child: Text('Dashboard')),
            PopupMenuItem(value: '/users', child: Text('Users')),
          ];
        }
        return const [
          PopupMenuItem(value: '/', child: Text('Home')),
          PopupMenuItem(value: '/login', child: Text('Login')),
          PopupMenuItem(value: '/signup', child: Text('Sign up')),
        ];
      },
    );
  }
}
