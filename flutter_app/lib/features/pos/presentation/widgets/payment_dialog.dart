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

  // Single selection state
  int? _selectedMethodId;
  int? _selectedCurrencyId;
  final TextEditingController _amountController =
      TextEditingController(text: '0.00');
  // Additional payment lines (multi-method)
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
    try {
      final results = await Future.wait([
        methodRepo.getMethods(),
        methodRepo.getMethodCurrencies(),
        repo.getCurrencies(),
      ]);
      _methods = results[0] as List<PaymentMethodDto>;
      _methodCurrencies = results[1] as Map<int, List<Map<String, dynamic>>>;
      _currencies = results[2] as List<CurrencyDto>;
      _baseCurrency = _currencies.firstWhere(
        (c) => c.isBase,
        orElse: () => _currencies.isNotEmpty
            ? _currencies.first
            : CurrencyDto(
                currencyId: 0,
                code: 'BASE',
                symbol: null,
                isBase: true,
                exchangeRate: 1.0,
              ),
      );
      _selectedMethodId = _methods.isNotEmpty ? _methods.first.methodId : null;
      _selectedCurrencyId = _baseCurrency?.currencyId;
      final total = ref.read(posNotifierProvider).total;
      _amountController.text = total.toStringAsFixed(2);
      _ensureAllowedCurrency();
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
    // Credit handling omitted in simplified UI

    return AlertDialog(
      title: const Text('Payment'),
      content: SizedBox(
        width: 720,
        height: 520,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Methods as horizontally scrollable radio row
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _methods
                              .map(
                                (m) => Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: InkWell(
                                    onTap: () => setState(() {
                                      _selectedMethodId = m.methodId;
                                      _ensureAllowedCurrency();
                                    }),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<int>(
                                          value: m.methodId,
                                          groupValue: _selectedMethodId,
                                          onChanged: (v) => setState(() {
                                            _selectedMethodId = v;
                                            _ensureAllowedCurrency();
                                          }),
                                        ),
                                        Text(m.name),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    // Amount input with currency picker prefix and clear suffix
                    TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: InkWell(
                          onTap: () async {
                            final picked = await _pickCurrencyFor(context, _selectedMethodId);
                            if (picked != null) {
                              setState(() => _selectedCurrencyId = picked);
                            }
                          },
                          child: Container(
                            alignment: Alignment.center,
                            width: 80,
                            child: Text(
                              _codeFor(_selectedCurrencyId),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                        suffixIcon: IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            setState(() => _amountController.text = '0.00');
                          },
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // Additional payments rows
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Additional Payments', style: Theme.of(context).textTheme.titleSmall),
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
                      ],
                    ),
                    ..._lines.asMap().entries.map((e) {
                      final idx = e.key;
                      final line = e.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                value: line.methodId,
                                items: _methods
                                    .map((m) => DropdownMenuItem<int>(
                                          value: m.methodId,
                                          child: Text(m.name),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  line.methodId = v;
                                  _ensureAllowedCurrencyForLine(line);
                                }),
                                decoration: const InputDecoration(labelText: 'Method'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 90,
                              child: TextButton(
                                onPressed: () async {
                                  final picked = await _pickCurrencyFor(context, line.methodId);
                                  if (picked != null) setState(() => line.currencyId = picked);
                                },
                                child: Text(_codeFor(line.currencyId), style: Theme.of(context).textTheme.titleMedium),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: line.controller,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Amount',
                                  suffixIcon: IconButton(
                                    tooltip: 'Clear',
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () => setState(() => line.controller.text = '0.00'),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: () => setState(() => _lines.removeAt(idx)),
                              icon: const Icon(Icons.remove_circle_outline_rounded),
                            )
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isChange ? 'Change' : 'Balance',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          displayBalance.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
                  final primaryMethod = _selectedMethodId;
                  if (primaryMethod == null) return;
                  setState(() => _submitting = true);
                  try {
                    final total = ref.read(posNotifierProvider).total;
                    final paidBase = _sumPaidInBase();
                    final paid = paidBase > total ? total : paidBase;
                    // Build payments: primary + additional lines
                    final payments = <PosPaymentLineDto>[
                      PosPaymentLineDto(
                        methodId: primaryMethod,
                        currencyId: _selectedCurrencyId,
                        amount: double.tryParse(_amountController.text.trim()) ?? 0.0,
                      ),
                      ..._lines.where((l) => l.methodId != null).map((l) => PosPaymentLineDto(
                            methodId: l.methodId!,
                            currencyId: l.currencyId,
                            amount: double.tryParse(l.controller.text.trim()) ?? 0.0,
                          )),
                    ];
                    final result = await ref
                        .read(posNotifierProvider.notifier)
                        .processCheckout(paymentMethodId: primaryMethod, paidAmount: paid, payments: payments);
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

  String _codeFor(int? currencyId) {
    final cur = _currencies.firstWhere(
      (c) => c.currencyId == currencyId,
      orElse: () => _baseCurrency ??
          CurrencyDto(
              currencyId: 0,
              code: 'BASE',
              symbol: null,
              isBase: true,
              exchangeRate: 1.0),
    );
    return cur.code;
  }

  double _rateFor(int? methodId, int? currencyId) {
    if (currencyId == null) return 1.0;
    final list = _methodCurrencies[methodId ?? -1] ?? const [];
    final found = list.firstWhere(
      (e) => e['currency_id'] == currencyId,
      orElse: () => const {'exchange_rate': null, 'rate': null},
    );
    final rate = (found['exchange_rate'] as num?)?.toDouble() ??
        (found['rate'] as num?)?.toDouble();
    if (rate != null) return rate;
    // Fallback to global currency rate
    final cur = _currencies.firstWhere((c) => c.currencyId == currencyId, orElse: () => _baseCurrency ?? CurrencyDto(currencyId: currencyId, code: 'CUR', symbol: null, isBase: false, exchangeRate: 1.0));
    return cur.exchangeRate;
  }

  double _sumPaidInBase() {
    double sum = 0.0;
    // primary line
    final pAmt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    sum += pAmt * _rateFor(_selectedMethodId, _selectedCurrencyId);
    // additional lines
    for (final l in _lines) {
      if (l.methodId == null) continue;
      final amt = double.tryParse(l.controller.text.trim()) ?? 0.0;
      sum += amt * _rateFor(l.methodId, l.currencyId);
    }
    return sum;
  }

  void _ensureAllowedCurrency() {
    final allowed = _allowedCurrenciesForMethod(_selectedMethodId);
    if (allowed.isEmpty) {
      _selectedCurrencyId = _baseCurrency?.currencyId;
    } else if (!allowed.contains(_selectedCurrencyId)) {
      _selectedCurrencyId = allowed.first;
    }
  }

  void _ensureAllowedCurrencyForLine(_PaymentLine line) {
    final allowed = _allowedCurrenciesForMethod(line.methodId);
    if (allowed.isEmpty) {
      line.currencyId = _baseCurrency?.currencyId;
    } else if (!allowed.contains(line.currencyId)) {
      line.currencyId = allowed.first;
    }
  }

  Future<int?> _pickCurrencyFor(BuildContext context, int? methodId) async {
    final allowed = _allowedCurrenciesForMethod(methodId);
    final subset = _currencies
        .where((c) => allowed.isEmpty || allowed.contains(c.currencyId))
        .toList();
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select Currency'),
          content: SizedBox(
            width: 360,
            height: 320,
            child: ListView.builder(
              itemCount: subset.length,
              itemBuilder: (_, i) {
                final c = subset[i];
                return ListTile(
                  title: Text(c.code),
                  subtitle: c.isBase
                      ? const Text('Base currency')
                      : Text('Rate: ${c.exchangeRate}'),
                  onTap: () => Navigator.of(ctx).pop(c.currencyId),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

class _PaymentLine {
  _PaymentLine({this.methodId, this.currencyId, required this.controller});
  int? methodId;
  int? currencyId;
  final TextEditingController controller;
}
