import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class NegativeStockApprovalRequiredException implements Exception {
  const NegativeStockApprovalRequiredException(this.message);

  final String message;

  @override
  String toString() => message;
}

NegativeStockApprovalRequiredException? parseNegativeStockApprovalRequired(
  Object error,
) {
  if (error is! DioException) return null;
  if (error.response?.statusCode != 403) return null;
  final data = error.response?.data;
  if (data is! Map<String, dynamic>) return null;
  final payload = data['data'];
  if (payload is! Map<String, dynamic>) return null;
  if (payload['code']?.toString() != 'NEGATIVE_STOCK_APPROVAL_REQUIRED') {
    return null;
  }
  final message = data['error']?.toString().trim().isNotEmpty == true
      ? data['error'].toString().trim()
      : (data['message']?.toString().trim().isNotEmpty == true
          ? data['message'].toString().trim()
          : 'Negative stock approval password required');
  return NegativeStockApprovalRequiredException(message);
}

Future<String?> showNegativeStockApprovalDialog(
  BuildContext context, {
  String title = 'Negative Stock Approval',
  String? message,
}) {
  final passwordController = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message?.trim().isNotEmpty == true
                ? message!.trim()
                : 'This action would reduce stock below zero. Enter the inventory approval password to continue.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Approval Password',
              prefixIcon: Icon(Icons.lock_rounded),
            ),
            onSubmitted: (_) {
              final password = passwordController.text.trim();
              Navigator.of(context).pop(password.isEmpty ? null : password);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final password = passwordController.text.trim();
            Navigator.of(context).pop(password.isEmpty ? null : password);
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}
