import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../utils/invoice_pdf.dart';
import '../../data/printer_settings_repository.dart';
import '../../utils/escpos.dart';
import '../../../../core/api_client.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/negative_stock_override.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/manager_override_dialog.dart';
import '../../../../shared/widgets/sales_action_password_dialog.dart';
import '../../../../shared/widgets/app_error_view.dart';

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
  Object? _error;
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
  String _redemptionType = 'DISCOUNT';
  final TextEditingController _redeemCtrl = TextEditingController(text: '0');
  final TextEditingController _couponCtrl = TextEditingController();
  PosCouponValidationDto? _validatedCoupon;
  bool _validatingCoupon = false;
  bool _autoFillRaffleCustomerData = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _redeemCtrl.dispose();
    _couponCtrl.dispose();
    for (final line in _lines) {
      line.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(posRepositoryProvider);
    final posState = ref.read(posNotifierProvider);
    final outbox = ref.read(outboxNotifierProvider);
    try {
      _methods = await repo.getPaymentMethods();
      _methodCurrencies = await repo.getPaymentMethodCurrencies();
      _currencies = await repo.getCurrencies();

      // Loyalty is optional; keep payment flow usable offline.
      LoyaltySettingsDto? settings;
      if (outbox.isOnline) {
        try {
          settings = await ref.read(loyaltyRepositoryProvider).getSettings();
        } catch (_) {
          settings = null;
        }
      }
      _minRedemption = settings?.minRedemptionPoints.toDouble() ?? 0.0;
      _minReserve = settings?.minPointsReserve.toDouble() ?? 0.0;
      _pointValue = settings?.pointValue ?? 0.01;
      _redemptionType = settings?.redemptionType ?? 'DISCOUNT';

      CustomerSummaryDto? summary;
      CustomerDto? customer;
      if (outbox.isOnline && posState.customer != null) {
        try {
          summary = await ref
              .read(customerRepositoryProvider)
              .getCustomerSummary(posState.customer!.customerId);
          customer = await ref
              .read(customerRepositoryProvider)
              .getCustomer(posState.customer!.customerId);
        } catch (_) {
          summary = null;
          customer = null;
        }
      }
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
      final total = ref.read(posNotifierProvider).total.abs();
      final defaultMethod =
          _methods.isNotEmpty ? _methods.first.methodId : null;
      final defaultCurrency = _baseCurrency?.currencyId;
      _lines.clear();
      final first = _PaymentLine(
        methodId: defaultMethod,
        currencyId: defaultCurrency,
        controller: TextEditingController(text: total.toStringAsFixed(2)),
      );
      _ensureAllowedCurrencyForLine(first);
      _lines.add(first);
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _syncPrimaryLineToTotal(double total) {
    if (_lines.isEmpty) return;
    _lines.first.controller.text = total.abs().toStringAsFixed(2);
  }

  Future<void> _validateCoupon(double saleAmount) async {
    final code = _couponCtrl.text.trim();
    if (code.isEmpty) {
      _showMessage('Enter a coupon code');
      return;
    }
    setState(() => _validatingCoupon = true);
    try {
      final coupon = await ref.read(posRepositoryProvider).validateCoupon(
            code: code,
            saleAmount: saleAmount,
            customerId: ref.read(posNotifierProvider).customer?.customerId,
          );
      if (!mounted) return;
      setState(() => _validatedCoupon = coupon);
      _syncPrimaryLineToTotal(
        (ref.read(posNotifierProvider).total -
                ((_useLoyalty
                            ? (double.tryParse(_redeemCtrl.text.trim()) ?? 0.0)
                            : 0.0)
                        .clamp(0.0, _availablePoints) *
                    _pointValue) -
                coupon.discountAmount)
            .clamp(0.0, double.infinity),
      );
      _showMessage(
        'Coupon applied: ${coupon.discountAmount.toStringAsFixed(2)} off',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _validatedCoupon = null);
      _showError(e);
    } finally {
      if (mounted) {
        setState(() => _validatingCoupon = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showError(Object error) {
    _showMessage(ErrorHandler.message(error));
  }

  List<Map<String, dynamic>> _printableRaffleCoupons(
      Map<String, dynamic> data) {
    final raw = (data['raffle_coupons'] as List<dynamic>? ?? const []);
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['print_after_invoice'] == true)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posNotifierProvider);
    final theme = Theme.of(context);
    final total = state.total;
    final isEditSession = state.isEditingSale;
    final hasRefundLines = state.hasRefundLines;
    final isRefundSettlement = total < 0;
    final allowDiscountRedemption =
        !isEditSession && _redemptionType == 'DISCOUNT';
    final redeemPts = allowDiscountRedemption && _useLoyalty
        ? (double.tryParse(_redeemCtrl.text.trim()) ?? 0.0)
        : 0.0;
    final redeemClamped = redeemPts.clamp(0.0, _availablePoints);
    final redeemValue = redeemClamped * _pointValue;
    final couponDiscount = _validatedCoupon?.discountAmount ?? 0.0;
    final effectiveTotal = hasRefundLines
        ? total
        : (total - redeemValue - couponDiscount).clamp(0.0, double.infinity);
    final effectiveSettlementAbs = effectiveTotal.abs();
    final paidBase = _sumPaidInBase();
    final balance = (effectiveSettlementAbs - paidBase);
    final isChange = !isRefundSettlement && balance < 0;
    final displayBalance = balance.abs();

    return Scaffold(
      appBar: AppBar(title: Text(isEditSession ? 'Save Sale' : 'Payment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppErrorView(
                  error: _error!,
                  title: 'Unable to load payment details',
                  onRetry: _bootstrap,
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hasRefundLines &&
                            !isEditSession &&
                            _availablePoints > 0 &&
                            allowDiscountRedemption) ...[
                          Row(children: [
                            Checkbox(
                                value: _useLoyalty,
                                onChanged: (v) => setState(() {
                                      _useLoyalty = (v ?? false);
                                      _validatedCoupon = null;
                                      if (_lines.isNotEmpty) {
                                        final newTotal = (state.total -
                                                ((_useLoyalty
                                                            ? (double.tryParse(
                                                                    _redeemCtrl
                                                                        .text
                                                                        .trim()) ??
                                                                0.0)
                                                            : 0.0)
                                                        .clamp(0.0,
                                                            _availablePoints) *
                                                    _pointValue))
                                            .clamp(0.0, double.infinity);
                                        _lines.first.controller.text =
                                            newTotal.toStringAsFixed(2);
                                      }
                                    })),
                            const Text('Redeem loyalty points'),
                          ]),
                          Row(children: [
                            Chip(
                                label: Text(
                                    'Avail: ${_availablePoints.toStringAsFixed(0)} pts')),
                            const SizedBox(width: 8),
                            Chip(
                                label: Text(
                                    'Value/pt: ${_pointValue.toStringAsFixed(2)}')),
                          ]),
                          Row(children: [
                            SizedBox(
                              width: 180,
                              child: TextField(
                                controller: _redeemCtrl,
                                enabled: _useLoyalty,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Points to redeem'),
                                onChanged: (_) => setState(() {
                                  _validatedCoupon = null;
                                  if (_lines.isNotEmpty) {
                                    final newTotal = (state.total -
                                            ((double.tryParse(_redeemCtrl.text
                                                            .trim()) ??
                                                        0.0)
                                                    .clamp(
                                                        0.0, _availablePoints) *
                                                _pointValue))
                                        .clamp(0.0, double.infinity);
                                    _lines.first.controller.text =
                                        newTotal.toStringAsFixed(2);
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
                                      final needed = (_pointValue > 0)
                                          ? (state.total / _pointValue)
                                          : 0.0;
                                      final clamped =
                                          needed.clamp(0.0, _availablePoints);
                                      setState(() {
                                        _redeemCtrl.text =
                                            clamped.toStringAsFixed(0);
                                        _validatedCoupon = null;
                                        _syncPrimaryLineToTotal(
                                          (state.total -
                                                  (clamped * _pointValue))
                                              .clamp(0.0, double.infinity),
                                        );
                                      });
                                    },
                              child: const Text('Full bill'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: !_useLoyalty
                                  ? null
                                  : () {
                                      setState(() {
                                        _redeemCtrl.text =
                                            _availablePoints.toStringAsFixed(0);
                                        _validatedCoupon = null;
                                        _syncPrimaryLineToTotal(
                                          (state.total -
                                                  (_availablePoints *
                                                      _pointValue))
                                              .clamp(0.0, double.infinity),
                                        );
                                      });
                                    },
                              child: const Text('Full available'),
                            ),
                          ]),
                          if (_useLoyalty) ...[
                            Slider(
                              value:
                                  (double.tryParse(_redeemCtrl.text.trim()) ??
                                          0.0)
                                      .clamp(0.0, _availablePoints),
                              min: 0.0,
                              max:
                                  _availablePoints > 0 ? _availablePoints : 0.0,
                              divisions: _availablePoints > 0
                                  ? _availablePoints.toInt().clamp(1, 1000)
                                  : 1,
                              label: _redeemCtrl.text,
                              onChanged: (v) => setState(() {
                                _redeemCtrl.text = v.toStringAsFixed(0);
                                _validatedCoupon = null;
                                if (_lines.isNotEmpty) {
                                  final newTotal = (state.total -
                                          (v.clamp(0.0, _availablePoints) *
                                              _pointValue))
                                      .clamp(0.0, double.infinity);
                                  _lines.first.controller.text =
                                      newTotal.toStringAsFixed(2);
                                }
                              }),
                            ),
                          ],
                          const Divider(height: 24),
                        ],
                        if (!hasRefundLines &&
                            !isEditSession &&
                            _availablePoints > 0 &&
                            !allowDiscountRedemption) ...[
                          Card(
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const ListTile(
                              leading: Icon(Icons.redeem_rounded),
                              title: Text('Loyalty gift redemption enabled'),
                              subtitle: Text(
                                'Point discounts are disabled here. Use the loyalty gift redeem page instead.',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (!hasRefundLines && !isEditSession) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _couponCtrl,
                                          decoration: InputDecoration(
                                            labelText: 'Coupon Code',
                                            hintText:
                                                'Validate coupon for this payment',
                                            suffixIcon: IconButton(
                                              tooltip: 'Clear coupon',
                                              onPressed: () {
                                                setState(() {
                                                  _couponCtrl.clear();
                                                  _validatedCoupon = null;
                                                  _syncPrimaryLineToTotal(
                                                    (state.total - redeemValue)
                                                        .clamp(0.0,
                                                            double.infinity),
                                                  );
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.clear_rounded,
                                              ),
                                            ),
                                          ),
                                          onChanged: (_) {
                                            if (_validatedCoupon != null) {
                                              setState(() {
                                                _validatedCoupon = null;
                                                _syncPrimaryLineToTotal(
                                                  (state.total - redeemValue)
                                                      .clamp(
                                                          0.0, double.infinity),
                                                );
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      FilledButton.icon(
                                        onPressed: _validatingCoupon
                                            ? null
                                            : () => _validateCoupon(
                                                  (total - redeemValue).clamp(
                                                    0.0,
                                                    double.infinity,
                                                  ),
                                                ),
                                        icon: _validatingCoupon
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.local_offer_outlined,
                                              ),
                                        label: const Text('Apply'),
                                      ),
                                    ],
                                  ),
                                  if (_validatedCoupon != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _validatedCoupon!.seriesName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Code ${_validatedCoupon!.code} • '
                                            '${_validatedCoupon!.discountType} • '
                                            'Discount ${_validatedCoupon!.discountAmount.toStringAsFixed(2)}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          Card(
                            elevation: 0,
                            color: theme.colorScheme.secondaryContainer
                                .withValues(alpha: 0.35),
                            child: ListTile(
                              leading: Icon(Icons.undo_rounded),
                              title:
                                  Text('Refund / edit authorization required'),
                              subtitle: Text(
                                isEditSession
                                    ? 'Coupon and loyalty discounts are disabled while editing an existing sale.'
                                    : 'Coupon and loyalty discounts are disabled when refund lines are included in the settlement.',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _autoFillRaffleCustomerData,
                          onChanged: state.customer == null
                              ? null
                              : (value) {
                                  setState(() =>
                                      _autoFillRaffleCustomerData = value);
                                },
                          title: const Text(
                            'Auto-fill raffle customer data',
                          ),
                          subtitle: Text(
                            state.customer == null
                                ? 'Select a customer to pre-fill raffle slips after invoice.'
                                : 'Use the selected customer on issued raffle coupons.',
                          ),
                        ),

                        // Payments header + Add button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Payments',
                                style: Theme.of(context).textTheme.titleSmall),
                            TextButton.icon(
                              onPressed: () => setState(() {
                                final l = _PaymentLine(
                                  methodId: _methods.isNotEmpty
                                      ? _methods.first.methodId
                                      : null,
                                  currencyId: _baseCurrency?.currencyId,
                                  controller:
                                      TextEditingController(text: '0.00'),
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
                                              padding: const EdgeInsets.only(
                                                  right: 16.0),
                                              child: InkWell(
                                                onTap: () => setState(() {
                                                  line.methodId = m.methodId;
                                                  _ensureAllowedCurrencyForLine(
                                                      line);
                                                }),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      line.methodId ==
                                                              m.methodId
                                                          ? Icons
                                                              .radio_button_checked
                                                          : Icons
                                                              .radio_button_unchecked,
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
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Amount',
                                          prefixIcon: InkWell(
                                            onTap: () async {
                                              final picked =
                                                  await _pickCurrencyFor(
                                                      context, line.methodId);
                                              if (picked != null) {
                                                setState(() =>
                                                    line.currencyId = picked);
                                              }
                                            },
                                            child: Container(
                                              alignment: Alignment.center,
                                              width: 80,
                                              child: Text(
                                                _codeFor(line.currencyId),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                            ),
                                          ),
                                          suffixIcon: IconButton(
                                            tooltip: 'Clear',
                                            icon:
                                                const Icon(Icons.clear_rounded),
                                            onPressed: () => setState(() =>
                                                line.controller.text = '0.00'),
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
                                          : () => setState(
                                              () => _lines.removeAt(idx)),
                                      icon: const Icon(
                                          Icons.remove_circle_outline_rounded),
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
                            Text('Bill Total',
                                style: Theme.of(context).textTheme.bodyLarge),
                            Text(total.toStringAsFixed(2),
                                style: Theme.of(context).textTheme.bodyLarge),
                          ],
                        ),
                        if (!hasRefundLines &&
                            !isEditSession &&
                            redeemValue > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Loyalty Discount',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                              Text('- ${redeemValue.toStringAsFixed(2)}',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ],
                        if (!hasRefundLines &&
                            !isEditSession &&
                            couponDiscount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Coupon Discount',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                              Text('- ${couponDiscount.toStringAsFixed(2)}',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                isRefundSettlement
                                    ? 'Refund Total'
                                    : 'Amount Due',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(effectiveSettlementAbs.toStringAsFixed(2),
                                style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Paid',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(_sumPaidInBase().toStringAsFixed(2),
                                style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                isRefundSettlement
                                    ? 'Refund Remaining'
                                    : (isChange ? 'Change' : 'Due'),
                                style: Theme.of(context).textTheme.titleSmall),
                            Text(displayBalance.toStringAsFixed(2),
                                style: Theme.of(context).textTheme.titleSmall),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(spacing: 12, children: [
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            FilledButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () async {
                                      setState(() => _submitting = true);
                                      try {
                                        final primaryMethod =
                                            _primaryMethodIdFromLines();
                                        final paid = _sumPaidInBase();
                                        // Clamp redeem points
                                        double? redeemPoints;
                                        if (_useLoyalty &&
                                            _availablePoints > 0) {
                                          final want = double.tryParse(
                                                  _redeemCtrl.text.trim()) ??
                                              0.0;
                                          final clamped =
                                              want.clamp(0.0, _availablePoints);
                                          redeemPoints =
                                              clamped > 0 ? clamped : null;
                                        }
                                        final payments = _lines
                                            .where((l) => l.methodId != null)
                                            .map((l) => PosPaymentLineDto(
                                                  methodId: l.methodId!,
                                                  currencyId: l.currencyId,
                                                  amount: double.tryParse(l
                                                          .controller.text
                                                          .trim()) ??
                                                      0.0,
                                                ))
                                            .toList();

                                        Future<PosCheckoutResult> runCheckout({
                                          String? overrideToken,
                                          String? overrideReason,
                                          String? salesActionPassword,
                                          String? overridePassword,
                                        }) {
                                          final cart = ref
                                              .read(posNotifierProvider)
                                              .cart;
                                          if (cart.any((item) =>
                                              !item.hasTrackingConfigured)) {
                                            throw StateError(
                                              'Configure batch / serial details for all tracked items before checkout.',
                                            );
                                          }
                                          if (!hasRefundLines &&
                                              !isEditSession &&
                                              _couponCtrl.text
                                                  .trim()
                                                  .isNotEmpty &&
                                              _validatedCoupon == null) {
                                            throw StateError(
                                              'Validate the coupon before checkout.',
                                            );
                                          }
                                          return ref
                                              .read(
                                                  posNotifierProvider.notifier)
                                              .processCheckout(
                                                paymentMethodId: primaryMethod,
                                                paidAmount: paid,
                                                payments: payments,
                                                redeemPoints: redeemPoints,
                                                couponCode:
                                                    _validatedCoupon?.code,
                                                autoFillRaffleCustomerData: state
                                                            .customer ==
                                                        null
                                                    ? null
                                                    : _autoFillRaffleCustomerData,
                                                managerOverrideToken:
                                                    overrideToken,
                                                overrideReason: overrideReason,
                                                salesActionPassword:
                                                    salesActionPassword,
                                                overridePassword:
                                                    overridePassword,
                                              );
                                        }

                                        PosCheckoutResult result;
                                        String? salesActionPassword;
                                        if (hasRefundLines || isEditSession) {
                                          salesActionPassword =
                                              await showSalesActionPasswordDialog(
                                            context,
                                            title: hasRefundLines &&
                                                    isRefundSettlement
                                                ? 'Authorize Refund'
                                                : isEditSession
                                                    ? 'Authorize Sale Edit'
                                                    : 'Authorize Edit / Exchange',
                                            message:
                                                'Enter the separate edit/refund PIN or password configured for your user.',
                                            actionLabel: 'Authorize',
                                          );
                                          if (!context.mounted) return;
                                          if (salesActionPassword == null) {
                                            setState(() => _submitting = false);
                                            return;
                                          }
                                        }
                                        try {
                                          result = await runCheckout(
                                            salesActionPassword:
                                                salesActionPassword,
                                          );
                                        } on DioException catch (e) {
                                          final data = e.response?.data;
                                          final maybe = (data is Map &&
                                                  data['data'] is Map)
                                              ? Map<String, dynamic>.from(
                                                  data['data'] as Map)
                                              : null;
                                          if (e.response?.statusCode == 403 &&
                                              maybe?['code'] ==
                                                  'OVERRIDE_REQUIRED') {
                                            if (!context.mounted) return;
                                            final perms =
                                                (maybe?['required_permissions']
                                                            as List?)
                                                        ?.map(
                                                            (x) => x.toString())
                                                        .toList() ??
                                                    const <String>[];
                                            final needReason =
                                                maybe?['reason_required'] ==
                                                    true;
                                            final approved =
                                                await showManagerOverrideDialog(
                                              context,
                                              ref,
                                              title:
                                                  'Manager override required',
                                              requiredPermissions: perms,
                                              requireReason: needReason,
                                              reasonLabel: 'Reason',
                                            );
                                            if (!context.mounted) return;
                                            if (approved == null) {
                                              if (!context.mounted) return;
                                              setState(
                                                  () => _submitting = false);
                                              return;
                                            }
                                            result = await runCheckout(
                                              overrideToken:
                                                  approved.overrideToken,
                                              overrideReason: approved.reason,
                                              salesActionPassword:
                                                  salesActionPassword,
                                            );
                                          } else {
                                            rethrow;
                                          }
                                        } on NegativeStockApprovalRequiredException catch (e) {
                                          if (!context.mounted) return;
                                          final password =
                                              await showNegativeStockApprovalDialog(
                                            context,
                                            message: e.message,
                                          );
                                          if (!context.mounted) return;
                                          if (password == null ||
                                              password.isEmpty) {
                                            setState(() => _submitting = false);
                                            return;
                                          }
                                          result = await runCheckout(
                                            salesActionPassword:
                                                salesActionPassword,
                                            overridePassword: password,
                                          );
                                        } on NegativeProfitApprovalRequiredException catch (e) {
                                          if (!context.mounted) return;
                                          final password =
                                              await showNegativeProfitApprovalDialog(
                                            context,
                                            message: e.message,
                                          );
                                          if (!context.mounted) return;
                                          if (password == null ||
                                              password.isEmpty) {
                                            setState(() => _submitting = false);
                                            return;
                                          }
                                          result = await runCheckout(
                                            salesActionPassword:
                                                salesActionPassword,
                                            overridePassword: password,
                                          );
                                        }
                                        if (!mounted) return;
                                        setState(() => _submitting = false);

                                        if (result.unchanged) {
                                          _showMessage(
                                            'No changes were detected. The existing sale was left unchanged.',
                                          );
                                          if (!context.mounted) return;
                                          Navigator.of(context).pop();
                                          return;
                                        }

                                        await _showSuccessDialog(result);

                                        if (!context.mounted) return;
                                        Navigator.of(context)
                                            .pop(); // back to POS for next sale
                                      } on OutboxQueuedException catch (e) {
                                        if (!context.mounted) return;
                                        setState(() => _submitting = false);
                                        await showDialog<void>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title:
                                                const Text('Queued for Sync'),
                                            content: Text(e.message),
                                            actions: [
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(),
                                                child: const Text('OK'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (!context.mounted) return;
                                        Navigator.of(context).pop();
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        setState(() => _submitting = false);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  ErrorHandler.message(e))),
                                        );
                                      }
                                    },
                              icon: _submitting
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.check_circle_rounded),
                              label: Text(
                                isEditSession ? 'Save Changes' : 'Finalize',
                              ),
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
    Map<String, dynamic>? printData;
    try {
      printData = await ref
          .read(posRepositoryProvider)
          .getPrintData(invoiceId: result.saleId);
    } catch (_) {
      printData = null;
    }
    final raffleCount =
        printData == null ? 0 : _printableRaffleCoupons(printData).length;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            result.updatedExistingSale ? 'Sale Updated' : 'Payment Successful',
          ),
          content: Text(
            result.updatedExistingSale
                ? 'Invoice ${result.saleNumber} updated'
                : raffleCount > 0
                    ? 'Invoice ${result.saleNumber} created.\n$raffleCount raffle coupon(s) issued.'
                    : 'Invoice ${result.saleNumber} created',
          ),
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
                  final data = await ref
                      .read(posRepositoryProvider)
                      .getPrintData(invoiceId: result.saleId);
                  final sale = (data['sale'] as Map<String, dynamic>? ?? {});
                  final company =
                      (data['company'] as Map<String, dynamic>? ?? {});
                  final raffleCoupons = _printableRaffleCoupons(data);
                  final logoUrl = _resolveLogoUrl(company);
                  final bytes = await InvoicePdfBuilder.buildPdfFromHtml(
                      sale, company,
                      format: PdfPageFormat.a4,
                      logoUrl: logoUrl,
                      raffleCoupons: raffleCoupons);
                  final dir = await getTemporaryDirectory();
                  final fileName =
                      'Invoice-${sale['sale_number'] ?? result.saleNumber}.pdf';
                  final path = '${dir.path}/$fileName';
                  final file = File(path);
                  await file.writeAsBytes(bytes, flush: true);
                  await Share.shareXFiles(
                    [XFile(path, name: fileName, mimeType: 'application/pdf')],
                    subject:
                        'Invoice ${sale['sale_number'] ?? result.saleNumber}',
                    text: 'Please find the attached invoice.',
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ErrorHandler.message(e))),
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
    final data = await ref
        .read(posRepositoryProvider)
        .getPrintData(invoiceId: result.saleId);
    final sale = (data['sale'] as Map<String, dynamic>? ?? {});
    final company = (data['company'] as Map<String, dynamic>? ?? {});
    final raffleCoupons = _printableRaffleCoupons(data);
    final printers =
        await ref.read(printerSettingsRepositoryProvider).loadAll();

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
                    leading: Icon(p.kind.startsWith('thermal')
                        ? Icons.print_rounded
                        : Icons.picture_as_pdf_rounded),
                    title: Text(p.name),
                    subtitle:
                        Text('${p.kind.toUpperCase()} • ${p.connectionType}'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _printToPrinter(p, sale, company, raffleCoupons);
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
                          onLayout: (format) =>
                              InvoicePdfBuilder.buildPdfFromWidgets(
                                  sale, company,
                                  format: PdfPageFormat.a4,
                                  logoUrl: logoUrl,
                                  raffleCoupons: raffleCoupons),
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
    final data = await ref
        .read(posRepositoryProvider)
        .getPrintData(invoiceId: result.saleId);
    final sale = (data['sale'] as Map<String, dynamic>? ?? {});
    final company = (data['company'] as Map<String, dynamic>? ?? {});
    final raffleCoupons = _printableRaffleCoupons(data);
    final printers =
        await ref.read(printerSettingsRepositoryProvider).loadAll();
    PrinterDevice? target;
    if (printers.length == 1) {
      target = printers.first;
    } else {
      target = printers.firstWhere((p) => p.isDefault,
          orElse: () => PrinterDevice(
              id: '', name: '', kind: 'a4', connectionType: 'system'));
      if (target.id.isEmpty) target = null;
    }
    if (target != null) {
      await _printToPrinter(target, sale, company, raffleCoupons);
    } else {
      await _showPrintOptions(result);
    }
  }

  Future<void> _printToPrinter(
      PrinterDevice p,
      Map<String, dynamic> sale,
      Map<String, dynamic> company,
      List<Map<String, dynamic>> raffleCoupons) async {
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
              raffleCoupons: raffleCoupons,
            );
          } else if (p.connectionType == 'bluetooth') {
            await printThermalOverBluetooth(
              sale: sale,
              company: company,
              settings: p,
              paperSize: size,
              raffleCoupons: raffleCoupons,
            );
          } else if (p.connectionType == 'usb') {
            await printThermalOverUsb(
              sale: sale,
              company: company,
              settings: p,
              paperSize: size,
              raffleCoupons: raffleCoupons,
            );
          } else {
            throw Exception('Unsupported connection type: ${p.connectionType}');
          }
          break;
        case 'a5':
          final logoUrl = _resolveLogoUrl(company);
          await Printing.layoutPdf(
            onLayout: (format) => InvoicePdfBuilder.buildPdfFromWidgets(
                sale, company,
                format: PdfPageFormat.a5,
                logoUrl: logoUrl,
                raffleCoupons: raffleCoupons),
          );
          break;
        case 'a4':
        default:
          final logoUrl = _resolveLogoUrl(company);
          await Printing.layoutPdf(
            onLayout: (format) => InvoicePdfBuilder.buildPdfFromWidgets(
                sale, company,
                format: PdfPageFormat.a4,
                logoUrl: logoUrl,
                raffleCoupons: raffleCoupons),
          );
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Printed via ${p.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
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
    if (methodId == null) {
      return _baseCurrency != null ? [_baseCurrency!.currencyId] : <int>[];
    }
    final list = _methodCurrencies[methodId] ?? const [];
    if (list.isEmpty) {
      return _baseCurrency != null ? [_baseCurrency!.currencyId] : <int>[];
    }
    return list.map((e) => e['currency_id'] as int).toList();
  }

  String _codeFor(int? currencyId) {
    final cur = _currencies.firstWhere(
      (c) => c.currencyId == currencyId,
      orElse: () =>
          _baseCurrency ??
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
    final cur = _currencies.firstWhere((c) => c.currencyId == currencyId,
        orElse: () =>
            _baseCurrency ??
            CurrencyDto(
                currencyId: currencyId,
                code: 'CUR',
                symbol: null,
                isBase: false,
                exchangeRate: 1.0));
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
