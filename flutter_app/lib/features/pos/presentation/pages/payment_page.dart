import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../utils/invoice_pdf.dart';
import '../../data/printer_settings_repository.dart';
import '../../utils/escpos.dart';
import '../../../../core/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/data/payment_methods_repository.dart';
import '../../controllers/pos_notifier.dart';
import '../../data/pos_repository.dart';
import '../../data/models.dart';
import '../../../customers/data/customer_repository.dart';
import '../../../customers/data/models.dart';
import '../../../loyalty/data/loyalty_repository.dart';

class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key});

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  bool _loading = true;
  bool _submitting = false;

  // Company-defined payment methods and their allowed currencies
  List<PaymentMethodDto> _methods = const [];
  Map<int, List<Map<String, dynamic>>> _methodCurrencies = const {};
  List<CurrencyDto> _currencies = const [];
  CurrencyDto? _baseCurrency;

  // Payment lines (each with method, currency, amount)
  final List<_PaymentLine> _lines = [];

  // Loyalty redemption
  bool _useLoyalty = false;
  double _availablePoints = 0.0;
  double _minRedemption = 0.0;
  double _minReserve = 0.0;
  double _pointValue = 0.01;
  final TextEditingController _redeemCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(posRepositoryProvider);
    final methodRepo = ref.read(paymentMethodsRepositoryProvider);
    final posState = ref.read(posNotifierProvider);
    try {
      final results = await Future.wait([
        methodRepo.getMethods(),
        methodRepo.getMethodCurrencies(),
        repo.getCurrencies(),
        // Loyalty settings
        ref.read(loyaltyRepositoryProvider).getSettings(),
        // Customer info for points if selected
        if (posState.customer != null)
          ref.read(customerRepositoryProvider).getCustomerSummary(posState.customer!.customerId)
        else
          Future.value(null),
        if (posState.customer != null)
          ref.read(customerRepositoryProvider).getCustomer(posState.customer!.customerId)
        else
          Future.value(null),
      ]);
      _methods = results[0] as List<PaymentMethodDto>;
      _methodCurrencies = results[1] as Map<int, List<Map<String, dynamic>>>;
      _currencies = results[2] as List<CurrencyDto>;
      final settings = results[3] as LoyaltySettingsDto;
      _minRedemption = settings.minRedemptionPoints.toDouble();
      _minReserve = settings.minPointsReserve.toDouble();
      _pointValue = settings.pointValue;
      final summary = results[4] as CustomerSummaryDto?;
      final customer = results[5] as CustomerDto?;
      if (summary != null && customer != null && customer.isLoyalty) {
        // Compute available points = max(0, current - reserve)
        final current = summary.loyaltyPoints;
        final redeemable = current - _minReserve;
        _availablePoints = redeemable > 0 ? redeemable : 0;
        if (_availablePoints < _minRedemption) {
          _availablePoints = 0;
        }
      } else {
        _availablePoints = 0;
      }
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
      final total = ref.read(posNotifierProvider).total;
      final defaultMethod = _methods.isNotEmpty ? _methods.first.methodId : null;
      final defaultCurrency = _baseCurrency?.currencyId;
      _lines.clear();
      final first = _PaymentLine(
        methodId: defaultMethod,
        currencyId: defaultCurrency,
        controller: TextEditingController(text: total.toStringAsFixed(2)),
      );
      _ensureAllowedCurrencyForLine(first);
      _lines.add(first);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posNotifierProvider);
    final total = state.total;
    final redeemPts = _useLoyalty ? (double.tryParse(_redeemCtrl.text.trim()) ?? 0.0) : 0.0;
    final redeemClamped = redeemPts.clamp(0.0, _availablePoints);
    final redeemValue = redeemClamped * _pointValue;
    final effectiveTotal = (total - redeemValue).clamp(0.0, double.infinity);
    final paidBase = _sumPaidInBase();
    final balance = (effectiveTotal - paidBase);
    final isChange = balance < 0;
    final displayBalance = balance.abs();

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_availablePoints > 0) ...[
                      Row(children: [
                        Checkbox(
                            value: _useLoyalty,
                            onChanged: (v) => setState(() {
                                  _useLoyalty = (v ?? false);
                                  if (_lines.isNotEmpty) {
                                    final newTotal = (state.total - ((_useLoyalty ? (double.tryParse(_redeemCtrl.text.trim()) ?? 0.0) : 0.0).clamp(0.0, _availablePoints) * _pointValue)).clamp(0.0, double.infinity);
                                    _lines.first.controller.text = newTotal.toStringAsFixed(2);
                                  }
                                })),
                        const Text('Redeem loyalty points'),
                      ]),
                      Row(children: [
                        Chip(label: Text('Avail: ${_availablePoints.toStringAsFixed(0)} pts')),
                        const SizedBox(width: 8),
                        Chip(label: Text('Value/pt: ${_pointValue.toStringAsFixed(2)}')),
                      ]),
                      Row(children: [
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: _redeemCtrl,
                            enabled: _useLoyalty,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Points to redeem'),
                            onChanged: (_) => setState(() {
                              if (_lines.isNotEmpty) {
                                final newTotal = (state.total - ((double.tryParse(_redeemCtrl.text.trim()) ?? 0.0).clamp(0.0, _availablePoints) * _pointValue)).clamp(0.0, double.infinity);
                                _lines.first.controller.text = newTotal.toStringAsFixed(2);
                              }
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('= ${redeemValue.toStringAsFixed(2)}'),
                      ]),
                      Row(children: [
                        TextButton(
                          onPressed: !_useLoyalty
                              ? null
                              : () {
                                  final needed = (_pointValue > 0) ? (state.total / _pointValue) : 0.0;
                                  final clamped = needed.clamp(0.0, _availablePoints);
                                  setState(() => _redeemCtrl.text = clamped.toStringAsFixed(0));
                                },
                          child: const Text('Full bill'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: !_useLoyalty
                              ? null
                              : () {
                                  setState(() => _redeemCtrl.text = _availablePoints.toStringAsFixed(0));
                                },
                          child: const Text('Full available'),
                        ),
                      ]),
                      if (_useLoyalty) ...[
                        Slider(
                          value: (double.tryParse(_redeemCtrl.text.trim()) ?? 0.0).clamp(0.0, _availablePoints),
                          min: 0.0,
                          max: _availablePoints > 0 ? _availablePoints : 0.0,
                          divisions: _availablePoints > 0 ? _availablePoints.toInt().clamp(1, 1000) : 1,
                          label: _redeemCtrl.text,
                          onChanged: (v) => setState(() {
                            _redeemCtrl.text = v.toStringAsFixed(0);
                            if (_lines.isNotEmpty) {
                              final newTotal = (state.total - (v.clamp(0.0, _availablePoints) * _pointValue)).clamp(0.0, double.infinity);
                              _lines.first.controller.text = newTotal.toStringAsFixed(2);
                            }
                          }),
                        ),
                      ],
                      const Divider(height: 24),
                    ],

                    // Payments header + Add button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payments', style: Theme.of(context).textTheme.titleSmall),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            final l = _PaymentLine(
                              methodId: _methods.isNotEmpty ? _methods.first.methodId : null,
                              currencyId: _baseCurrency?.currencyId,
                              controller: TextEditingController(text: '0.00'),
                            );
                            _ensureAllowedCurrencyForLine(l);
                            _lines.add(l);
                          }),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Payment'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Render each payment block
                    ..._lines.asMap().entries.map((e) {
                      final idx = e.key;
                      final line = e.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _methods
                                    .map((m) => Padding(
                                          padding: const EdgeInsets.only(right: 16.0),
                                          child: InkWell(
                                            onTap: () => setState(() {
                                              line.methodId = m.methodId;
                                              _ensureAllowedCurrencyForLine(line);
                                            }),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  line.methodId == m.methodId
                                                      ? Icons.radio_button_checked
                                                      : Icons.radio_button_unchecked,
                                                  size: 20,
                                                ),
                                                Text(m.name),
                                              ],
                                            ),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: line.controller,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Amount',
                                      prefixIcon: InkWell(
                                        onTap: () async {
                                          final picked = await _pickCurrencyFor(context, line.methodId);
                                          if (picked != null) setState(() => line.currencyId = picked);
                                        },
                                        child: Container(
                                          alignment: Alignment.center,
                                          width: 80,
                                          child: Text(
                                            _codeFor(line.currencyId),
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                        ),
                                      ),
                                      suffixIcon: IconButton(
                                        tooltip: 'Clear',
                                        icon: const Icon(Icons.clear_rounded),
                                        onPressed: () => setState(() => line.controller.text = '0.00'),
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: _lines.length == 1
                                      ? null
                                      : () => setState(() => _lines.removeAt(idx)),
                                  icon: const Icon(Icons.remove_circle_outline_rounded),
                                )
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Paid', style: Theme.of(context).textTheme.titleMedium),
                        Text(_sumPaidInBase().toStringAsFixed(2), style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isChange ? 'Change' : 'Due', style: Theme.of(context).textTheme.titleSmall),
                        Text(displayBalance.toStringAsFixed(2), style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(spacing: 12, children: [
                        TextButton(
                          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        FilledButton.icon(
                          onPressed: _submitting
                              ? null
                              : () async {
                                  setState(() => _submitting = true);
                                  try {
                                    final primaryMethod = _primaryMethodIdFromLines();
                                    final paid = _sumPaidInBase();
                                    // Clamp redeem points
                                    double? redeemPoints;
                                    if (_useLoyalty && _availablePoints > 0) {
                                      final want = double.tryParse(_redeemCtrl.text.trim()) ?? 0.0;
                                      final clamped = want.clamp(0.0, _availablePoints);
                                      redeemPoints = clamped > 0 ? clamped : null;
                                    }
                                    final payments = _lines
                                        .where((l) => l.methodId != null)
                                        .map((l) => PosPaymentLineDto(
                                              methodId: l.methodId!,
                                              currencyId: l.currencyId,
                                              amount: double.tryParse(l.controller.text.trim()) ?? 0.0,
                                            ))
                                        .toList();

                                    final result = await ref
                                        .read(posNotifierProvider.notifier)
                                        .processCheckout(
                                          paymentMethodId: primaryMethod,
                                          paidAmount: paid,
                                          payments: payments,
                                          redeemPoints: redeemPoints,
                                        );
                                    if (!mounted) return;
                                    setState(() => _submitting = false);

                                    await _showSuccessDialog(result);

                                    if (!mounted) return;
                                    Navigator.of(context).pop(); // back to POS for next sale
                                  } catch (e) {
                                    if (!mounted) return;
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
                      ]),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _showSuccessDialog(PosCheckoutResult result) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Payment Successful'),
          content: Text('Invoice ${result.saleNumber} created'),
          actions: [
            TextButton(
              onPressed: () async {
                await _printSmart(result);
              },
              child: const Text('Print'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final data = await ref.read(posRepositoryProvider).getPrintData(invoiceId: result.saleId);
                  final sale = (data['sale'] as Map<String, dynamic>? ?? {});
                  final company = (data['company'] as Map<String, dynamic>? ?? {});
                  final logoUrl = _resolveLogoUrl(company);
                  final bytes = await InvoicePdfBuilder.buildPdfFromHtml(sale, company, format: PdfPageFormat.a4, logoUrl: logoUrl);
                  final dir = await getTemporaryDirectory();
                  final fileName = 'Invoice-${sale['sale_number'] ?? result.saleNumber}.pdf';
                  final path = '${dir.path}/$fileName';
                  final file = File(path);
                  await file.writeAsBytes(bytes, flush: true);
                  await Share.shareXFiles(
                    [XFile(path, name: fileName, mimeType: 'application/pdf')],
                    subject: 'Invoice ${sale['sale_number'] ?? result.saleNumber}',
                    text: 'Please find the attached invoice.',
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to share: $e')),
                    );
                  }
                }
              },
              child: const Text('Share Invoice'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPrintOptions(PosCheckoutResult result) async {
    final data = await ref.read(posRepositoryProvider).getPrintData(invoiceId: result.saleId);
    final sale = (data['sale'] as Map<String, dynamic>? ?? {});
    final company = (data['company'] as Map<String, dynamic>? ?? {});
    final printers = await ref.read(printerSettingsRepositoryProvider).loadAll();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: const Text('Select Printer'), dense: true),
              ...printers.map((p) => ListTile(
                    leading: Icon(p.kind.startsWith('thermal') ? Icons.print_rounded : Icons.picture_as_pdf_rounded),
                    title: Text(p.name),
                    subtitle: Text('${p.kind.toUpperCase()} • ${p.connectionType}'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _printToPrinter(p, sale, company);
                    },
                  )),
              if (printers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(children: [
                    const Text('No printers configured. Printing to A4.'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final logoUrl = _resolveLogoUrl(company);
                        await Printing.layoutPdf(
                          onLayout: (format) => InvoicePdfBuilder.buildPdfFromWidgets(sale, company, format: PdfPageFormat.a4, logoUrl: logoUrl),
                        );
                      },
                      child: const Text('Print A4 Now'),
                    ),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _printSmart(PosCheckoutResult result) async {
    final data = await ref.read(posRepositoryProvider).getPrintData(invoiceId: result.saleId);
    final sale = (data['sale'] as Map<String, dynamic>? ?? {});
    final company = (data['company'] as Map<String, dynamic>? ?? {});
    final printers = await ref.read(printerSettingsRepositoryProvider).loadAll();
    PrinterDevice? target;
    if (printers.length == 1) {
      target = printers.first;
    } else {
      target = printers.firstWhere((p) => p.isDefault, orElse: () => PrinterDevice(id: '', name: '', kind: 'a4', connectionType: 'system'));
      if (target.id.isEmpty) target = null;
    }
    if (target != null) {
      await _printToPrinter(target, sale, company);
    } else {
      await _showPrintOptions(result);
    }
  }

  Future<void> _printToPrinter(PrinterDevice p, Map<String, dynamic> sale, Map<String, dynamic> company) async {
    try {
      switch (p.kind) {
        case 'thermal_80':
        case 'thermal_58':
          final size = p.kind == 'thermal_80' ? '80mm' : '58mm';
          if (p.connectionType == 'network') {
            await printThermalOverTcp(
              sale: sale,
              company: company,
              settings: p,
              paperSize: size,
            );
          } else if (p.connectionType == 'bluetooth') {
            await printThermalOverBluetooth(
              sale: sale,
              company: company,
              settings: p,
              paperSize: size,
            );
          } else if (p.connectionType == 'usb') {
            await printThermalOverUsb(
              sale: sale,
              company: company,
              settings: p,
              paperSize: size,
            );
          } else {
            throw Exception('Unsupported connection type: ${p.connectionType}');
          }
          break;
        case 'a5':
          final logoUrl = _resolveLogoUrl(company);
          await Printing.layoutPdf(
            onLayout: (format) => InvoicePdfBuilder.buildPdfFromWidgets(sale, company, format: PdfPageFormat.a5, logoUrl: logoUrl),
          );
          break;
        case 'a4':
        default:
          final logoUrl = _resolveLogoUrl(company);
          await Printing.layoutPdf(
            onLayout: (format) => InvoicePdfBuilder.buildPdfFromWidgets(sale, company, format: PdfPageFormat.a4, logoUrl: logoUrl),
          );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Printed via ${p.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print failed: $e')));
      }
    }
  }

  String? _resolveLogoUrl(Map<String, dynamic> company) {
    final logo = company['logo'] as String?;
    if (logo == null || logo.isEmpty) return null;
    try {
      final dio = ref.read(dioProvider);
      var base = dio.options.baseUrl;
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      if (base.endsWith('/api/v1')) {
        base = base.substring(0, base.length - '/api/v1'.length);
      }
      final url = logo.startsWith('http') ? logo : (base + logo);
      return url;
    } catch (_) {
      return null;
    }
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
    final rate = (found['exchange_rate'] as num?)?.toDouble() ?? (found['rate'] as num?)?.toDouble();
    if (rate != null) return rate;
    final cur = _currencies.firstWhere((c) => c.currencyId == currencyId, orElse: () => _baseCurrency ?? CurrencyDto(currencyId: currencyId, code: 'CUR', symbol: null, isBase: false, exchangeRate: 1.0));
    return cur.exchangeRate;
  }

  double _sumPaidInBase() {
    double sum = 0.0;
    for (final l in _lines) {
      if (l.methodId == null) continue;
      final amt = double.tryParse(l.controller.text.trim()) ?? 0.0;
      sum += amt * _rateFor(l.methodId, l.currencyId);
    }
    return sum;
  }

  int? _primaryMethodIdFromLines() {
    if (_lines.isEmpty) return null;
    double best = -1.0;
    int? chosen;
    for (final l in _lines) {
      if (l.methodId == null) continue;
      final amt = double.tryParse(l.controller.text.trim()) ?? 0.0;
      final base = amt * _rateFor(l.methodId, l.currencyId);
      if (base > best) {
        best = base;
        chosen = l.methodId;
      }
    }
    return chosen ?? _lines.first.methodId;
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
    final subset = _currencies.where((c) => allowed.isEmpty || allowed.contains(c.currencyId)).toList();
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
                  subtitle: c.isBase ? const Text('Base currency') : Text('Rate: ${c.exchangeRate}'),
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

