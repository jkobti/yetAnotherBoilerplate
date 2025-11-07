import 'package:flutter/material.dart';

import '../core/widgets/app_scaffold.dart';

class DocumentationPage extends StatelessWidget {
  const DocumentationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleInfo(title: 'Documentation');
  }
}

class _SimpleInfo extends StatelessWidget {
  final String title;
  const _SimpleInfo({required this.title});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text('This page is coming soon.', style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
