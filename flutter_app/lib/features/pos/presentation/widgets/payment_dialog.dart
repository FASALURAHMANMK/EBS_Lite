import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/data/payment_methods_repository.dart';
import '../../controllers/pos_notifier.dart';
import '../../data/pos_repository.dart';
import '../../data/models.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({super.key});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  bool _loading = true;
  bool _submitting = false;

  // Company-defined payment methods and their allowed currencies
  List<PaymentMethodDto> _methods = const [];
  Map<int, List<Map<String, dynamic>>> _methodCurrencies = const {};
  List<CurrencyDto> _currencies = const [];
  CurrencyDto? _baseCurrency;

  // Optional: customer credit
  CustomerDetailDto? _customer;

  // Multiple payment lines
  final List<_PaymentLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(posRepositoryProvider);
    final methodRepo = ref.read(paymentMethodsRepositoryProvider);
    final total = ref.read(posNotifierProvider).total;
    final custId = ref.read(posNotifierProvider).customer?.customerId;
    try {
      final results = await Future.wait([
        methodRepo.getMethods(),
        methodRepo.getMethodCurrencies(),
        repo.getCurrencies(),
        if (custId != null) repo.getCustomerDetail(custId),
      ]);
      _methods = results[0] as List<PaymentMethodDto>;
      _methodCurrencies = results[1] as Map<int, List<Map<String, dynamic>>>;
      _currencies = results[2] as List<CurrencyDto>;
      if (results.length > 3) _customer = results[3] as CustomerDetailDto;
      _baseCurrency = _currencies.firstWhere((c) => c.isBase, orElse: () => _currencies.isNotEmpty ? _currencies.first : CurrencyDto(currencyId: 0, code: 'BASE', symbol: null, isBase: true, exchangeRate: 1.0));
      // Seed with one line defaulting to first method + base currency
      final defaultMethod = _methods.isNotEmpty ? _methods.first.methodId : null;
      final defaultCurrency = _baseCurrency?.currencyId;
      _lines.add(_PaymentLine(methodId: defaultMethod, currencyId: defaultCurrency, controller: TextEditingController(text: total.toStringAsFixed(2))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posNotifierProvider);
    final total = state.total;
    final paidBase = _sumPaidInBase();
    final balance = (total - paidBase);
    final isChange = balance < 0;
    final displayBalance = balance.abs();
    final eligibleCredit = _isCreditEligible(balance);

    return AlertDialog(
      title: const Text('Payment'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._lines.map((line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                value: line.methodId,
                                items: _methods
                                    .map((m) => DropdownMenuItem<int>(value: m.methodId, child: Text(m.name)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  line.methodId = v;
                                  // Reset currency to base if not allowed
                                  final allowed = _allowedCurrenciesForMethod(v);
                                  if (allowed.isNotEmpty) {
                                    if (!allowed.contains(line.currencyId)) {
                                      line.currencyId = allowed.first;
                                    }
                                  } else {
                                    line.currencyId = _baseCurrency?.currencyId;
                                  }
                                }),
                                decoration: const InputDecoration(labelText: 'Method'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<int>(
                                value: line.currencyId ?? _baseCurrency?.currencyId,
                                items: _currencyMenuForMethod(line.methodId),
                                onChanged: (v) => setState(() => line.currencyId = v),
                                decoration: const InputDecoration(labelText: 'Currency'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: line.controller,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Amount'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            IconButton(
                              onPressed: _lines.length == 1
                                  ? null
                                  : () => setState(() {
                                        _lines.remove(line);
                                      }),
                              icon: const Icon(Icons.remove_circle_outline),
                              tooltip: 'Remove',
                            )
                          ],
                        ),
                      )),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 8, children: [
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _lines.add(_PaymentLine(
                            methodId: _methods.isNotEmpty ? _methods.first.methodId : null,
                            currencyId: _baseCurrency?.currencyId,
                            controller: TextEditingController(text: '0.00'),
                          ));
                        }),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Payment'),
                      ),
                      if (eligibleCredit)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            // Add or adjust a CREDIT line for the remaining balance
                            final creditMethod = _methods.firstWhere(
                              (m) => m.type.toUpperCase() == 'CREDIT',
                              orElse: () => _methods.first,
                            );
                            final remaining = (state.total - _sumPaidInBase()).clamp(0.0, 1e12);
                            _lines.add(_PaymentLine(
                              methodId: creditMethod.methodId,
                              currencyId: _baseCurrency?.currencyId,
                              controller: TextEditingController(text: remaining.toStringAsFixed(2)),
                            ));
                          }),
                          icon: const Icon(Icons.credit_score_rounded),
                          label: const Text('Use Credit'),
                        ),
                    ]),
                  ),
                  const Divider(height: 16),
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
                  final primaryMethod = _primaryMethodId();
                  if (primaryMethod == null) return;
                  setState(() => _submitting = true);
                  try {
                    final paid = _sumPaidInBase();
                    final result = await ref
                        .read(posNotifierProvider.notifier)
                        .processCheckout(paymentMethodId: primaryMethod, paidAmount: paid);
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

  List<int> _allowedCurrenciesForMethod(int? methodId) {
    if (methodId == null) return _baseCurrency != null ? [_baseCurrency!.currencyId] : <int>[];
    final list = _methodCurrencies[methodId] ?? const [];
    if (list.isEmpty) {
      return _baseCurrency != null ? [_baseCurrency!.currencyId] : <int>[];
    }
    return list.map((e) => e['currency_id'] as int).toList();
  }

  List<DropdownMenuItem<int>> _currencyMenuForMethod(int? methodId) {
    final allowed = _allowedCurrenciesForMethod(methodId);
    final subset = _currencies.where((c) => allowed.contains(c.currencyId)).toList();
    return subset.map((c) => DropdownMenuItem<int>(value: c.currencyId, child: Text(c.code))).toList();
  }

  double _rateFor(int? methodId, int? currencyId) {
    if (currencyId == null) return 1.0;
    final list = _methodCurrencies[methodId ?? -1] ?? const [];
    final found = list.firstWhere(
      (e) => e['currency_id'] == currencyId,
      orElse: () => {'exchange_rate': null},
    );
    final rate = (found['exchange_rate'] as num?)?.toDouble();
    if (rate != null) return rate;
    // Fallback to global currency rate
    final cur = _currencies.firstWhere((c) => c.currencyId == currencyId, orElse: () => _baseCurrency ?? CurrencyDto(currencyId: currencyId, code: 'CUR', symbol: null, isBase: false, exchangeRate: 1.0));
    return cur.exchangeRate;
  }

  double _sumPaidInBase() {
    double sum = 0.0;
    for (final l in _lines) {
      final amt = double.tryParse(l.controller.text.trim()) ?? 0.0;
      final rate = _rateFor(l.methodId, l.currencyId);
      sum += amt * rate;
    }
    return sum;
  }

  bool _isCreditEligible(double remainingBalance) {
    if (_customer == null) return false;
    if (remainingBalance <= 0) return false;
    final available = (_customer!.creditLimit - _customer!.creditBalance);
    return available >= remainingBalance - 0.01; // small epsilon
  }

  int? _primaryMethodId() {
    if (_lines.isEmpty) return null;
    // Prefer the method from the largest non-credit line; else any line
    _lines.sort((a, b) {
      final av = (double.tryParse(a.controller.text.trim()) ?? 0.0) * _rateFor(a.methodId, a.currencyId);
      final bv = (double.tryParse(b.controller.text.trim()) ?? 0.0) * _rateFor(b.methodId, b.currencyId);
      return bv.compareTo(av);
    });
    return _lines.first.methodId;
  }
}

class _PaymentLine {
  _PaymentLine({this.methodId, this.currencyId, required this.controller});
  int? methodId;
  int? currencyId;
  final TextEditingController controller;
}
