import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_handler.dart';
import '../../features/auth/controllers/auth_notifier.dart';

class ManagerOverrideResult {
  final int userId;
  final String username;
  ManagerOverrideResult({required this.userId, required this.username});
}

Future<ManagerOverrideResult?> showManagerOverrideDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required List<String> requiredPermissions,
}) async {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  return showDialog<ManagerOverrideResult?>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      var busy = false;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Manager username or email',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        final ident = usernameController.text.trim();
                        final res = await ref
                            .read(authRepositoryProvider)
                            .verifyCredentials(
                              username: ident.contains('@') ? null : ident,
                              email: ident.contains('@') ? ident : null,
                              password: passwordController.text,
                              requiredPermissions: requiredPermissions,
                            );
                        if (!context.mounted) return;
                        Navigator.of(context).pop(
                          ManagerOverrideResult(
                            userId: res.userId,
                            username: res.username,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        setState(() => busy = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ErrorHandler.message(e))),
                        );
                      }
                    },
              child: Text(busy ? 'Verifying...' : 'Approve'),
            ),
          ],
        ),
      );
    },
  );
}
