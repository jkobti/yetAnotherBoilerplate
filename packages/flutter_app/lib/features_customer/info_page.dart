import 'package:flutter/material.dart';

import '../core/widgets/app_scaffold.dart';

class InfoPage extends StatelessWidget {
  final String title;
  final String? description;

  const InfoPage({super.key, required this.title, this.description});

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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  description ?? 'This page is coming soon.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
