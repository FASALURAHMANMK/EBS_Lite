import 'package:flutter/material.dart';

import '../../core/error_handler.dart';
import 'app_message_view.dart';
import 'no_network_view.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.title = 'Something went wrong',
  });

  final Object error;
  final VoidCallback? onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (ErrorHandler.isNetworkError(error)) {
      return NoNetworkView(
        onRetry: onRetry,
        message: 'You appear to be offline. Please check your connection.',
      );
    }

    return AppMessageView(
      icon: Icons.error_outline_rounded,
      title: title,
      message: ErrorHandler.message(error),
      onRetry: onRetry,
    );
  }
}
