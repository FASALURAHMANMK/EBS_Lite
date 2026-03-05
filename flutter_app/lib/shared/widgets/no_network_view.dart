import 'package:flutter/material.dart';

import 'app_message_view.dart';

class NoNetworkView extends StatelessWidget {
  const NoNetworkView({
    super.key,
    this.onRetry,
    this.title = 'No internet connection',
    this.message = 'Connect to the internet to continue.',
  });

  final VoidCallback? onRetry;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppMessageView(
      icon: Icons.wifi_off_rounded,
      title: title,
      message: message,
      onRetry: onRetry,
    );
  }
}
