import 'package:flutter/material.dart';

import '../../core/outbox/outbox_state.dart';
import 'no_network_view.dart';

class NetworkRequiredGate extends StatelessWidget {
  const NetworkRequiredGate({
    super.key,
    required this.outbox,
    required this.child,
    required this.onRetry,
    required this.offlineMessage,
    this.offlineTitle = 'No internet connection',
  });

  final OutboxState outbox;
  final Widget child;
  final VoidCallback onRetry;
  final String offlineTitle;
  final String offlineMessage;

  @override
  Widget build(BuildContext context) {
    if (outbox.isChecking) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Checking connection…'),
            ],
          ),
        ),
      );
    }

    if (!outbox.isOnline) {
      return NoNetworkView(
        onRetry: onRetry,
        title: offlineTitle,
        message: offlineMessage,
      );
    }

    return child;
  }
}
