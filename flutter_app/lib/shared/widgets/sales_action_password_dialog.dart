import 'package:flutter/material.dart';

Future<String?> showSalesActionPasswordDialog(
  BuildContext context, {
  required String title,
  String? message,
  String actionLabel = 'Continue',
}) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((message ?? '').trim().isNotEmpty) ...[
              Text(message!.trim()),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Edit / Refund PIN or Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) {
                if ((value ?? '').trim().length < 4) {
                  return 'Enter at least 4 characters';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(controller.text.trim());
            }
          },
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}
