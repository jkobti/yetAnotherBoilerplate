import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Container(
          width: double.infinity,
          color: colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 700;
                  return isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ColumnBlock(title: 'Product', children: _productLinks(context, textTheme)),
                            const SizedBox(height: 16),
                            _ColumnBlock(title: 'Resources', children: _resourcesLinks(context, textTheme)),
                            const SizedBox(height: 16),
                            _ColumnBlock(title: 'Company', children: _companyLinks(context, textTheme)),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _ColumnBlock(title: 'Product', children: _productLinks(context, textTheme))),
                            Expanded(child: _ColumnBlock(title: 'Resources', children: _resourcesLinks(context, textTheme))),
                            Expanded(child: _ColumnBlock(title: 'Company', children: _companyLinks(context, textTheme))),
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _productLinks(BuildContext context, TextTheme textTheme) {
    return [
      _FooterLink(label: 'Features', onTap: () => context.go('/features')),
      _FooterLink(label: 'Use Cases', onTap: () => context.go('/use-cases')),
      _FooterLink(label: 'Pricing', onTap: () => context.go('/pricing')),
      _FooterLink(label: 'Dashboard', onTap: () => context.go('/app')),
    ];
  }

  List<Widget> _resourcesLinks(BuildContext context, TextTheme textTheme) {
    return [
      _FooterLink(label: 'Documentation', onTap: () => context.go('/documentation')),
      _FooterLink(label: 'API Reference', onTap: () => context.go('/api-reference')),
      _FooterLink(label: 'Blog', onTap: () => context.go('/blog')),
      _FooterLink(label: 'Support', onTap: () => context.go('/support')),
    ];
  }

  List<Widget> _companyLinks(BuildContext context, TextTheme textTheme) {
    return [
      _FooterLink(label: 'About us', onTap: () => context.go('/about')),
      _FooterLink(label: 'Careers', onTap: () => context.go('/careers')),
      _FooterLink(label: 'Privacy Policy', onTap: () => context.go('/privacy')),
      _FooterLink(label: 'Terms and conditions', onTap: () => context.go('/terms')),
    ];
  }
}

class _ColumnBlock extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ColumnBlock({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return TextButton(
      style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: color)),
    );
  }
}
