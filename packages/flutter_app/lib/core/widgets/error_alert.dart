import 'package:flutter/material.dart';

/// A reusable, styled error alert component following Material 3 best practices.
///
/// Features:
/// - Material 3 design with proper spacing and typography
/// - Optional close button for dismissible errors
/// - Icon and color coding for error severity
/// - Accessible text contrast and sizing
/// - Smooth animations and rounded corners
class ErrorAlert extends StatelessWidget {
  /// The error message to display
  final String message;

  /// Whether to show a close button (optional, defaults to false)
  final bool dismissible;

  /// Callback when close button is pressed
  final VoidCallback? onDismiss;

  /// Optional custom title (defaults to "Error")
  final String? title;

  /// Optional icon (defaults to error_outline)
  final IconData? icon;

  /// Optional background color (defaults to error with opacity)
  final Color? backgroundColor;

  /// Optional text color (defaults to dark error)
  final Color? textColor;

  const ErrorAlert(
    this.message, {
    super.key,
    this.dismissible = false,
    this.onDismiss,
    this.title,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final errorContainer = theme.colorScheme.errorContainer;
    final onErrorContainer = theme.colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: errorColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Icon(
            icon ?? Icons.error_outline,
            color: errorColor,
            size: 20,
          ),
          const SizedBox(width: 12),

          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Optional title
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: textColor ?? onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // Error message
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor ?? onErrorContainer,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Optional close button
          if (dismissible && onDismiss != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close, color: errorColor),
                onPressed: onDismiss,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Variant for warning messages with a different color scheme
class WarningAlert extends StatelessWidget {
  final String message;
  final bool dismissible;
  final VoidCallback? onDismiss;

  const WarningAlert(
    this.message, {
    super.key,
    this.dismissible = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ErrorAlert(
      message,
      title: 'Warning',
      icon: Icons.warning_amber,
      backgroundColor: theme.colorScheme.warningContainer,
      textColor: theme.colorScheme.onWarningContainer,
      dismissible: dismissible,
      onDismiss: onDismiss,
    );
  }
}

/// Extension to provide convenient access to warning colors
extension WarningColorScheme on ColorScheme {
  Color get warningContainer => Color.alphaBlend(
        const Color(0xFFFFB81C).withOpacity(0.12),
        surface,
      );

  Color get onWarningContainer => const Color(0xFF664D00);
}
