import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme_controller.dart';
import '../../core/push/push_service.dart';
import '../auth/auth_state.dart';
import 'app_footer.dart';

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
    final auth = ref.watch(authStateProvider);
    final me = auth.valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              // Flip based on the current effective theme, so first click always changes
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
            },
          ),
          const SizedBox(width: 8),
          // Primary nav
          if (_isWide(context))
            ..._navActions(context, ref, me)
          else
            _navMenu(context, ref, me),
          const SizedBox(width: 8),
          if (PushService.isEnabled)
            IconButton(
              tooltip: 'Enable notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => PushService.initializeAndRegister(context),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  body,
                  if (!isAdmin) const AppFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isWide(BuildContext context) {
    return MediaQuery.of(context).size.width >= 720;
  }

  List<Widget> _navActions(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? me) {
    final isLoggedIn = me != null;
    if (isAdmin) {
      final isStaff = (me?['is_staff'] == true);
      if (isLoggedIn) {
        return [
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Dashboard'),
          ),
          if (isStaff)
            TextButton(
              onPressed: () => context.go('/users'),
              child: const Text('Users'),
            ),
          TextButton(
            onPressed: () async {
              await ref.read(authStateProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Logout'),
          ),
        ];
      } else {
        return [
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login'),
          ),
        ];
      }
    }
    if (isLoggedIn) {
      return [
        TextButton(
          onPressed: () => context.go('/app'),
          child: const Text('Home'),
        ),
        TextButton(
          onPressed: () => context.go('/profile'),
          child: const Text('Profile'),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(authStateProvider.notifier).signOut();
            if (context.mounted) context.go('/');
          },
          child: const Text('Logout'),
        ),
      ];
    } else {
      return [
        TextButton(
          onPressed: () => context.go('/app'),
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
  }

  Widget _navMenu(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? me) {
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      onSelected: (value) {
        if (value == '#toggle-theme') {
          ref.read(themeModeProvider.notifier).toggle();
          return;
        }
        if (value == '#logout') {
          ref.read(authStateProvider.notifier).signOut().then((_) {
            if (context.mounted) context.go('/');
          });
          return;
        }
        context.go(value);
      },
      itemBuilder: (context) {
        final isLoggedIn = me != null;
        if (isAdmin) {
          final isStaff = (me?['is_staff'] == true);
          if (isLoggedIn) {
            final items = <PopupMenuEntry<String>>[
              const PopupMenuItem(value: '/', child: Text('Dashboard')),
              if (isStaff)
                const PopupMenuItem(value: '/users', child: Text('Users')),
              const PopupMenuItem(value: '#logout', child: Text('Logout')),
              const PopupMenuItem(
                  value: '#toggle-theme', child: Text('Toggle theme')),
            ];
            return items;
          } else {
            return const [
              PopupMenuItem(value: '/login', child: Text('Login')),
              PopupMenuItem(
                  value: '#toggle-theme', child: Text('Toggle theme')),
            ];
          }
        }
        if (isLoggedIn) {
          return const [
            PopupMenuItem(value: '/app', child: Text('Home')),
            PopupMenuItem(value: '/profile', child: Text('Profile')),
            PopupMenuItem(value: '#logout', child: Text('Logout')),
            PopupMenuItem(value: '#toggle-theme', child: Text('Toggle theme')),
          ];
        } else {
          return const [
            PopupMenuItem(value: '/app', child: Text('Home')),
            PopupMenuItem(value: '/login', child: Text('Login')),
            PopupMenuItem(value: '/signup', child: Text('Sign up')),
            PopupMenuItem(value: '#toggle-theme', child: Text('Toggle theme')),
          ];
        }
      },
    );
  }
}
