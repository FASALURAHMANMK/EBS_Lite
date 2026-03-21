import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ebs_lite/core/error_handler.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/core/negative_stock_override.dart';
import 'package:ebs_lite/shared/widgets/app_error_view.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../dashboard/controllers/location_notifier.dart';
import '../../../loyalty/data/loyalty_repository.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../../pos/presentation/widgets/customer_selector_dialog.dart';
import '../../../inventory/data/models.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../../data/models.dart';
import '../../data/customer_repository.dart';

class LoyaltyGiftRedeemPage extends ConsumerStatefulWidget {
  const LoyaltyGiftRedeemPage({super.key});

  @override
  ConsumerState<LoyaltyGiftRedeemPage> createState() =>
      _LoyaltyGiftRedeemPageState();
}

class _LoyaltyGiftRedeemPageState extends ConsumerState<LoyaltyGiftRedeemPage> {
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loading = true;
  Object? _error;
  bool _searching = false;
  bool _submitting = false;

  LoyaltySettingsDto? _settings;
  PosCustomerDto? _customer;
  CustomerSummaryDto? _summary;
  List<PosProductDto> _results = const [];
  final List<_GiftRedeemLine> _lines = [];

  double get _availablePoints {
    final current = _summary?.loyaltyPoints ?? 0;
    final reserve = (_settings?.minPointsReserve ?? 0).toDouble();
    final available = current - reserve;
    if (available < (_settings?.minRedemptionPoints ?? 0)) return 0;
    return available > 0 ? available : 0;
  }

  double get _totalPoints =>
      _lines.fold(0, (sum, item) => sum + item.totalPoints);

  double get _totalValue =>
      _lines.fold(0, (sum, item) => sum + item.totalValue(_settings));

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await ref.read(loyaltyRepositoryProvider).getSettings();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _pickCustomer() async {
    final picked = await showDialog<PosCustomerDto>(
      context: context,
      builder: (_) => const CustomerSelectorDialog(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customer = picked;
      _summary = null;
      _lines.clear();
    });
    try {
      final repo = ref.read(customerRepositoryProvider);
      final detail = await repo.getCustomer(picked.customerId);
      final summary = await repo.getCustomerSummary(picked.customerId);
      if (!mounted) return;
      if (!detail.isLoyalty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected customer is not enrolled in loyalty.'),
          ),
        );
      }
      setState(() => _summary = summary);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(error))),
      );
    }
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final list =
          await ref.read(posRepositoryProvider).searchProducts(trimmed);
      if (!mounted) return;
      setState(() {
        _results = list
            .where((item) => !item.isVirtualCombo && item.isLoyaltyGift)
            .toList();
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(error))),
      );
    }
  }

  Future<double?> _promptQuantity(PosProductDto product, {double initial = 1}) {
    final controller = TextEditingController(
      text: initial == initial.roundToDouble()
          ? initial.toStringAsFixed(0)
          : initial.toStringAsFixed(3),
    );
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.displayLabel),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Quantity',
            helperText: 'Enter the gift quantity to redeem.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final quantity = double.tryParse(controller.text.trim());
              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid quantity.')),
                );
                return;
              }
              Navigator.of(context).pop(quantity);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _addGift(PosProductDto product) async {
    final quantity = await _promptQuantity(product);
    if (quantity == null || !mounted) return;
    final existingIndex = _lines.indexWhere(
      (line) => line.product.identityKey == product.identityKey,
    );
    setState(() {
      if (existingIndex >= 0 && !product.requiresTracking) {
        _lines[existingIndex] = _lines[existingIndex].copyWith(
          quantity: _lines[existingIndex].quantity + quantity,
        );
      } else {
        _lines.add(_GiftRedeemLine(product: product, quantity: quantity));
      }
      _results = const [];
      _searchController.clear();
    });
  }

  Future<void> _editLine(_GiftRedeemLine line) async {
    final quantity =
        await _promptQuantity(line.product, initial: line.quantity);
    if (quantity == null || !mounted) return;
    setState(() {
      final index = _lines.indexOf(line);
      if (index >= 0) {
        _lines[index] = line.copyWith(quantity: quantity, clearTracking: true);
      }
    });
  }

  Future<void> _configureTracking(_GiftRedeemLine line) async {
    final selection = await showInventoryTrackingSelector(
      context: context,
      ref: ref,
      productId: line.product.productId,
      productName: line.product.displayLabel,
      quantity: line.quantity,
      mode: InventoryTrackingMode.issue,
      initialSelection: line.tracking,
    );
    if (selection == null || !mounted) return;
    setState(() {
      final index = _lines.indexOf(line);
      if (index >= 0) {
        _lines[index] = line.copyWith(tracking: selection);
      }
    });
  }

  Future<bool> _ensureTrackingSelections() async {
    for (var index = 0; index < _lines.length; index++) {
      final line = _lines[index];
      if (!line.product.requiresTracking || line.tracking != null) continue;
      await _configureTracking(line);
      final latest = index < _lines.length ? _lines[index] : line;
      if (latest.product.requiresTracking && latest.tracking == null) {
        return false;
      }
    }
    return true;
  }

  Future<void> _submit({String? overridePassword}) async {
    final location = ref.read(locationNotifierProvider).selected;
    if (_customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer first.')),
      );
      return;
    }
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a location first.')),
      );
      return;
    }
    if ((_settings?.redemptionType ?? 'DISCOUNT') != 'GIFT') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gift redemption is disabled in loyalty settings.',
          ),
        ),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one loyalty gift.')),
      );
      return;
    }
    if (_totalPoints > _availablePoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selected gifts exceed available points.')),
      );
      return;
    }
    if (!await _ensureTrackingSelections()) return;

    setState(() => _submitting = true);
    try {
      final result = await ref.read(loyaltyRepositoryProvider).redeemGift(
            customerId: _customer!.customerId,
            locationId: location.locationId,
            notes: _notesController.text,
            overridePassword: overridePassword,
            items: _lines
                .map((line) => {
                      'product_id': line.product.productId,
                      if (line.product.barcodeId > 0)
                        'barcode_id': line.product.barcodeId,
                      'quantity': line.quantity,
                      if (line.tracking?.serialNumbers.isNotEmpty == true)
                        'serial_numbers': line.tracking!.serialNumbers,
                      if (line.tracking?.batchAllocations.isNotEmpty == true)
                        'batch_allocations': line.tracking!.batchAllocations
                            .map((e) => e.toJson())
                            .toList(),
                    })
                .toList(),
          );
      if (!mounted) return;
      setState(() {
        _lines.clear();
        _notesController.clear();
      });
      if (_customer != null) {
        final summary = await ref
            .read(customerRepositoryProvider)
            .getCustomerSummary(_customer!.customerId);
        if (mounted) {
          setState(() => _summary = summary);
        }
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gift Redemption Complete'),
          content: Text(result.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final stockApproval = parseNegativeStockApprovalRequired(error);
      if (stockApproval != null) {
        final password = await showNegativeStockApprovalDialog(
          context,
          message: stockApproval.message,
        );
        if (password != null && password.isNotEmpty) {
          await _submit(overridePassword: password);
        }
        return;
      }
      final profitApproval = parseNegativeProfitApprovalRequired(error);
      if (profitApproval != null) {
        final password = await showNegativeProfitApprovalDialog(
          context,
          message: profitApproval.message,
        );
        if (password != null && password.isNotEmpty) {
          await _submit(overridePassword: password);
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Loyalty Gift Redeem'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppErrorView(
                  error: _error!,
                  title: 'Failed to load loyalty gift redemption',
                  onRetry: _bootstrap,
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          runSpacing: 12,
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.swap_horiz_rounded),
                              label: Text(
                                'Mode: ${_settings?.redemptionType == 'GIFT' ? 'Gift Redemption' : 'Discount at Payment'}',
                              ),
                            ),
                            Chip(
                              avatar: const Icon(Icons.loyalty_rounded),
                              label: Text(
                                '${_settings?.pointsPerCurrency.toStringAsFixed(2) ?? '0'} pts / currency',
                              ),
                            ),
                            Chip(
                              avatar: const Icon(Icons.local_offer_outlined),
                              label: Text(
                                'Value/pt ${_settings?.pointValue.toStringAsFixed(2) ?? '0.00'}',
                              ),
                            ),
                            if ((_settings?.redemptionType ?? 'DISCOUNT') !=
                                'GIFT')
                              Text(
                                'Gift redemption is currently disabled. Change the loyalty redemption type to gift redemption first.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _customer == null
                                        ? 'No customer selected'
                                        : _customer!.name,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _pickCustomer,
                                  icon: const Icon(Icons.person_search_rounded),
                                  label: Text(
                                    _customer == null
                                        ? 'Select Customer'
                                        : 'Change Customer',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  label: Text(
                                    'Current: ${_summary?.loyaltyPoints.toStringAsFixed(0) ?? '0'} pts',
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    'Available: ${_availablePoints.toStringAsFixed(0)} pts',
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    'Reserve: ${(_settings?.minPointsReserve ?? 0)} pts',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search loyalty gifts',
                        hintText: 'Search by name or barcode',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onSubmitted: _search,
                    ),
                    const SizedBox(height: 8),
                    if (_searching)
                      const LinearProgressIndicator(minHeight: 2)
                    else if (_results.isNotEmpty)
                      Card(
                        elevation: 0,
                        child: Column(
                          children: _results
                              .map(
                                (item) => ListTile(
                                  title: Text(item.displayLabel),
                                  subtitle: Text(
                                    [
                                      'Stock ${item.stock.toStringAsFixed(3)}',
                                      '${item.loyaltyPointsRequired.toStringAsFixed(0)} pts',
                                      if ((item.primaryStorage ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        item.primaryStorage!,
                                    ].join(' • '),
                                  ),
                                  trailing: FilledButton(
                                    onPressed: () => _addGift(item),
                                    child: const Text('Add'),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Gifts',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            if (_lines.isEmpty)
                              const Text('No loyalty gifts selected yet.')
                            else
                              ..._lines.map(
                                (line) => Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: ListTile(
                                    title: Text(line.product.displayLabel),
                                    subtitle: Text(
                                      [
                                        'Qty ${line.quantity.toStringAsFixed(line.quantity % 1 == 0 ? 0 : 3)}',
                                        '${line.totalPoints.toStringAsFixed(0)} pts',
                                        if (line.product.requiresTracking)
                                          line.tracking == null
                                              ? 'Tracking required'
                                              : line.tracking!
                                                  .summary(line.quantity),
                                      ].join(' • '),
                                    ),
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit quantity',
                                          onPressed: () => _editLine(line),
                                          icon: const Icon(Icons.edit_rounded),
                                        ),
                                        if (line.product.requiresTracking)
                                          IconButton(
                                            tooltip: 'Tracking',
                                            onPressed: () =>
                                                _configureTracking(line),
                                            icon: const Icon(
                                              Icons.qr_code_scanner_rounded,
                                            ),
                                          ),
                                        IconButton(
                                          tooltip: 'Remove',
                                          onPressed: () => setState(
                                            () => _lines.remove(line),
                                          ),
                                          icon:
                                              const Icon(Icons.delete_outline),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _notesController,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                                hintText:
                                    'Optional notes for this gift redemption',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Total ${_totalPoints.toStringAsFixed(0)} pts',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ),
                                  Text(
                                    'Approx. value ${_totalValue.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: _submitting ? null : _submit,
                                icon: _submitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.redeem_rounded),
                                label: const Text('Redeem Gifts'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _GiftRedeemLine {
  const _GiftRedeemLine({
    required this.product,
    required this.quantity,
    this.tracking,
  });

  final PosProductDto product;
  final double quantity;
  final InventoryTrackingSelection? tracking;

  double get totalPoints => product.loyaltyPointsRequired * quantity;

  double totalValue(LoyaltySettingsDto? settings) =>
      totalPoints * (settings?.pointValue ?? 0);

  _GiftRedeemLine copyWith({
    double? quantity,
    InventoryTrackingSelection? tracking,
    bool clearTracking = false,
  }) {
    return _GiftRedeemLine(
      product: product,
      quantity: quantity ?? this.quantity,
      tracking: clearTracking ? null : (tracking ?? this.tracking),
    );
  }
}
