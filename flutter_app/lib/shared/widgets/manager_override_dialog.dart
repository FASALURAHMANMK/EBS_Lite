import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_handler.dart';
import '../../features/auth/controllers/auth_notifier.dart';

class ManagerOverrideResult {
  final int userId;
  final String username;
  final String overrideToken;
  final int? expiresAtUnix;
  final String? reason;

  ManagerOverrideResult({
    required this.userId,
    required this.username,
    required this.overrideToken,
    this.expiresAtUnix,
    this.reason,
  });
}

Future<ManagerOverrideResult?> showManagerOverrideDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required List<String> requiredPermissions,
  bool requireReason = false,
  String reasonLabel = 'Reason',
  String identityLabel = 'Manager username or email',
  String actionLabel = 'Approve',
}) async {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final reasonController = TextEditingController();

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
              if (requireReason) ...[
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: reasonLabel,
                    prefixIcon: const Icon(Icons.description_outlined),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: identityLabel,
                  prefixIcon: const Icon(Icons.person_rounded),
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
                        final reason = reasonController.text.trim();
                        if (requireReason && reason.isEmpty) {
                          if (!context.mounted) return;
                          setState(() => busy = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$reasonLabel is required')),
                          );
                          return;
                        }
                        final ident = usernameController.text.trim();
                        final res = await ref
                            .read(authRepositoryProvider)
                            .verifyCredentials(
                              username: ident.contains('@') ? null : ident,
                              email: ident.contains('@') ? ident : null,
                              password: passwordController.text,
                              requiredPermissions: requiredPermissions,
                            );
                        final token = res.overrideToken?.trim() ?? '';
                        if (token.isEmpty) {
                          throw Exception('Override token not returned');
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).pop(
                          ManagerOverrideResult(
                            userId: res.userId,
                            username: res.username,
                            overrideToken: token,
                            expiresAtUnix: res.expiresAtUnix,
                            reason: requireReason ? reason : null,
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
              child: Text(busy ? 'Verifying...' : actionLabel),
            ),
          ],
        ),
      );
    },
  );
}
