import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppSelectionDialog extends StatelessWidget {
  const AppSelectionDialog({
    super.key,
    required this.title,
    required this.body,
    this.searchField,
    this.loading = false,
    this.errorText,
    this.footer,
    this.actions,
    this.maxWidth = 560,
    this.maxHeight = 520,
  });

  final String title;
  final Widget body;
  final Widget? searchField;
  final bool loading;
  final String? errorText;
  final Widget? footer;
  final List<Widget>? actions;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math
        .max(
          math.min(maxWidth, size.width - 32),
          math.min(280, size.width - 32),
        )
        .toDouble();
    final height =
        math.max(280.0, math.min(maxHeight, size.height * 0.72)).toDouble();
    final theme = Theme.of(context);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(title),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      content: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            if (searchField != null) ...[
              searchField!,
              const SizedBox(height: 12),
            ],
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
            Expanded(child: body),
            if (footer != null) ...[
              const SizedBox(height: 12),
              footer!,
            ],
          ],
        ),
      ),
      actions: actions,
    );
  }
}
