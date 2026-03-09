import 'package:flutter/material.dart';

import 'app_message_view.dart';

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.onRetry,
    this.retryLabel = 'Refresh',
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return AppMessageView(
      icon: icon,
      title: title,
      message: message,
      onRetry: onRetry,
      retryLabel: retryLabel,
    );
  }
}
