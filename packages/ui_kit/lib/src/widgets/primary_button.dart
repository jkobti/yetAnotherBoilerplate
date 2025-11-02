import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key, required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: child,
    );
  }
}
