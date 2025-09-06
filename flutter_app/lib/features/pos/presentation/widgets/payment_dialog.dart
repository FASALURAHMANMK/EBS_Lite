import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/data/payment_methods_repository.dart';
import '../../controllers/pos_notifier.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({super.key});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  int? _methodId;
  late TextEditingController _amountController;
  double _paid = 0.0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final total = ref.read(posNotifierProvider).total;
    _paid = total;
    _amountController = TextEditingController(text: total.toStringAsFixed(2));
    final methods = ref.read(posNotifierProvider).paymentMethods;
    if (methods.isNotEmpty) _methodId = methods.first.methodId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posNotifierProvider);
    final total = state.total;
    final balance = (total - _paid);
    final isChange = balance < 0;
    final displayBalance = balance.abs();
    return AlertDialog(
      title: const Text('Payment'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _methodId,
              items: state.paymentMethods
                  .map((m) => DropdownMenuItem<int>(
                        value: m.methodId,
                        child: Text(m.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _methodId = v),
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount Received',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
              onChanged: (v) {
                final parsed = double.tryParse(v) ?? 0.0;
                setState(() => _paid = parsed);
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isChange ? 'Change' : 'Balance', style: Theme.of(context).textTheme.titleMedium),
                Text(displayBalance.toStringAsFixed(2), style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total'),
                Text(total.toStringAsFixed(2)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting
              ? null
              : () async {
                  if (_methodId == null) return;
                  setState(() => _submitting = true);
                  try {
                    final result = await ref
                        .read(posNotifierProvider.notifier)
                        .processCheckout(paymentMethodId: _methodId, paidAmount: _paid);
                    if (!mounted) return;
                    Navigator.of(context).pop(result);
                  } catch (e) {
                    setState(() => _submitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to process: $e')),
                    );
                  }
                },
          icon: _submitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_circle_rounded),
          label: const Text('Finalize'),
        ),
      ],
    );
  }
}

