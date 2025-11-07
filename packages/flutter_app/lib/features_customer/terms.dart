import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

import '../core/widgets/app_scaffold.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  Future<String> _loadMarkdown() {
    // For web, Flutter automatically prepends 'assets/', so we use the path without it
    final path = kIsWeb ? 'content/terms.md' : 'assets/content/terms.md';
    return rootBundle.loadString(path);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Terms and conditions',
      body: FutureBuilder<String>(
        future: _loadMarkdown(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Failed to load terms and conditions.'),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Markdown(
                  data: snapshot.data ?? '',
                  shrinkWrap: true,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
