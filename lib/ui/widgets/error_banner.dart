/// Felbanderoll med Swedish text och återhämtningsknapp
library;

import 'package:flutter/material.dart';
import '../../ui/theme/app_theme.dart';

class SwedishErrorBanner extends StatelessWidget {
  const SwedishErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.type = ErrorType.general,
  });

  final String message;
  final VoidCallback? onRetry;
  final ErrorType type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      ErrorType.warning => AppTheme.warningColor,
      ErrorType.info => AppTheme.brandBlue,
      _ => AppTheme.errorColor,
    };
    final icon = switch (type) {
      ErrorType.warning => Icons.warning_amber_rounded,
      ErrorType.info => Icons.info_outline_rounded,
      _ => Icons.error_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                  ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Försök igen'),
            ),
          ],
        ],
      ),
    );
  }
}

enum ErrorType { general, warning, info, network }
