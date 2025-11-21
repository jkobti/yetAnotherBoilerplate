import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_scaffold.dart';

class NotFoundPage extends StatelessWidget {
  final bool isAdmin;

  const NotFoundPage({super.key, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Page Not Found',
      isAdmin: isAdmin,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '404',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
