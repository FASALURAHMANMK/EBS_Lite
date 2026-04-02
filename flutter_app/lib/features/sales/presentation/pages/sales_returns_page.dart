import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';
import 'package:ebs_lite/shared/widgets/sales_action_password_dialog.dart';

import '../../../../core/error_handler.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/models.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../../../pos/controllers/pos_notifier.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../../pos/presentation/pages/pos_page.dart';
import '../../../pos/presentation/widgets/customer_selector_dialog.dart';
import '../../data/sales_repository.dart';
import 'sale_return_detail_page.dart';
import 'sale_detail_page.dart';

enum SaleReturnDocumentMode {
  saleReturn,
  refundInvoice,
}

class SaleReturnFormPage extends ConsumerStatefulWidget {
  const SaleReturnFormPage({
    super.key,
    this.initialSaleId,
    this.selectAllReturnable = false,
    this.mode = SaleReturnDocumentMode.saleReturn,
  });

  final int? initialSaleId;
  final bool selectAllReturnable;
  final SaleReturnDocumentMode mode;

  @override
  ConsumerState<SaleReturnFormPage> createState() => _SaleReturnFormPageState();
}

class _SaleReturnFormPageState extends ConsumerState<SaleReturnFormPage> {
  PosCustomerDto? _customer;
  SaleDto? _linkedSale;
  bool _linking = false;
  Object? _linkError;
  final _invoiceCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final List<_ReturnableLine> _returnableLines = [];
  final List<_RetLine> _lines = [
    _RetLine(),
  ];

  bool get _hasLinkedReturnableLines => _returnableLines.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final initialSaleId = widget.initialSaleId;
    if (initialSaleId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLinkedSale(initialSaleId, selectAll: widget.selectAllReturnable);
      });
    }
  }

  @override
  void dispose() {
    _invoiceCtrl.dispose();
    _reasonCtrl.dispose();
    for (final line in _returnableLines) {
      line.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _replaceReturnableLines(List<_ReturnableLine> next) {
    for (final line in _returnableLines) {
      line.dispose();
    }
    _returnableLines
      ..clear()
      ..addAll(next);
  }

  List<_ReturnableLine> _selectedReturnableLines() {
    return _returnableLines.where((line) {
      if (!line.selected) return false;
      final qty = double.tryParse(line.quantity.text.trim()) ?? 0;
      return qty > 0;
    }).toList(growable: false);
  }

  Future<void> _loadLinkedSale(
    int saleId, {
    bool selectAll = false,
  }) async {
    setState(() {
      _linking = true;
      _linkError = null;
    });
    try {
      final repo = ref.read(salesRepositoryProvider);
      final sale = await ref.read(posRepositoryProvider).getSaleById(saleId);
      final source = widget.mode == SaleReturnDocumentMode.refundInvoice
          ? await repo.getRefundableForSale(saleId)
          : await repo.getReturnableForSale(saleId);
      final items = ((widget.mode == SaleReturnDocumentMode.refundInvoice
                  ? source['refundable_items']
                  : source['returnable_items']) as List<dynamic>? ??
              const [])
          .whereType<Map>()
          .map((row) => _ReturnableLine.fromJson(
                Map<String, dynamic>.from(row),
                selectAll: selectAll,
              ))
          .where((line) => line.maxQuantity > 0)
          .toList();
      if (!mounted) return;
      setState(() {
        _linkedSale = sale;
        _invoiceCtrl.text = sale.saleNumber;
        if (sale.customerId != null &&
            (sale.customerName ?? '').trim().isNotEmpty) {
          _customer = PosCustomerDto(
            customerId: sale.customerId!,
            name: sale.customerName!,
          );
        } else {
          _customer = null;
        }
        _replaceReturnableLines(items);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _linkedSale = null;
        _replaceReturnableLines(const []);
        _linkError = error;
      });
    } finally {
      if (mounted) {
        setState(() => _linking = false);
      }
    }
  }

  Future<void> _findInvoice() async {
    final code = _invoiceCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _linking = true);
    try {
      final list = await ref
          .read(salesRepositoryProvider)
          .getSalesHistory(saleNumber: code);
      if (!mounted) return;
      if (list.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('No invoice found')));
        return;
      }
      final id = list.first['sale_id'] as int?;
      if (id == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('Invalid invoice selected')));
        return;
      }
      await _loadLinkedSale(id);
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _save() async {
    try {
      final items = <Map<String, dynamic>>[];
      if (_hasLinkedReturnableLines) {
        for (final line in _selectedReturnableLines()) {
          final qty = double.tryParse(line.quantity.text.trim()) ?? 0;
          if (qty <= 0) continue;
          if (qty > line.maxQuantity) {
            throw StateError(
              'Refund quantity for ${line.productName} cannot exceed ${line.maxQuantity.toStringAsFixed(2)}',
            );
          }
          items.add(widget.mode == SaleReturnDocumentMode.refundInvoice
              ? {
                  'sale_detail_id': line.saleDetailId,
                  'quantity': qty,
                }
              : {
                  'product_id': line.productId,
                  'quantity': qty,
                  'unit_price': line.unitPrice,
                  if (line.saleDetailId != null)
                    'sale_detail_id': line.saleDetailId,
                  if (line.barcodeId != null) 'barcode_id': line.barcodeId,
                });
        }
      } else {
        for (final l in _lines) {
          if (l.product == null) continue;
          final qty = double.tryParse(l.qty.text.trim()) ?? 0;
          if (qty <= 0) continue;
          final price = double.tryParse(l.price.text.trim()) ?? 0;
          if (price <= 0) continue;
          final tracking = l.tracking;
          if (tracking == null) {
            throw StateError(
              'Configure variation / tracking for ${l.product!.name}',
            );
          }
          items.add({
            'product_id': l.product!.productId,
            'quantity': qty,
            'unit_price': price,
            ...tracking.toReceiveJson(),
          });
        }
      }
      if (items.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('Enter items to return')));
        return;
      }

      final reason = _reasonCtrl.text.trim();
      if (reason.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Reason is required')));
        return;
      }

      final sale = _linkedSale;
      final overridePassword = await showSalesActionPasswordDialog(
        context,
        title: widget.mode == SaleReturnDocumentMode.refundInvoice
            ? 'Authorize Refund Invoice'
            : (sale == null ? 'Authorize Return' : 'Authorize Refund'),
        message:
            'Enter the separate edit/refund PIN or password configured for your user.',
        actionLabel: 'Authorize',
      );
      if (!mounted || overridePassword == null) return;

      if (widget.mode == SaleReturnDocumentMode.refundInvoice) {
        if (sale == null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text('Invoice number is required for refunds'),
            ));
          return;
        }
        final refundSaleId =
            await ref.read(salesRepositoryProvider).createRefundInvoice(
                  saleId: sale.saleId,
                  items: items,
                  reason: reason,
                  overridePassword: overridePassword,
                );
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SaleDetailPage(saleId: refundSaleId),
          ),
        );
        return;
      }

      final customer = _customer;
      int returnId;
      if (customer == null) {
        // Walk-in: invoice mandatory
        if (sale == null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
                content: Text('Invoice number required for walk-in returns')));
          return;
        }
        returnId = await ref.read(salesRepositoryProvider).createSaleReturn(
              saleId: sale.saleId,
              items: items,
              reason: reason,
              overridePassword: overridePassword,
            );
      } else {
        if (sale != null) {
          // Customer selected with invoice
          returnId = await ref.read(salesRepositoryProvider).createSaleReturn(
                saleId: sale.saleId,
                items: items,
                reason: reason,
                overridePassword: overridePassword,
              );
        } else {
          // Customer selected, invoice optional – let backend locate a sale
          returnId = await ref
              .read(salesRepositoryProvider)
              .createSaleReturnByCustomer(
                customerId: customer.customerId,
                items: items,
                reason: reason,
                overridePassword: overridePassword,
              );
        }
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => SaleReturnDetailPage(returnId: returnId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  Future<void> _openInSellScreen() async {
    try {
      final sale = _linkedSale;
      if (sale == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Load an invoice first')),
          );
        return;
      }
      final selected = _selectedReturnableLines();
      if (selected.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Select at least one invoice line')),
          );
        return;
      }

      final saleItems = {
        for (final item in sale.items)
          if (item.saleDetailId != null)
            item.saleDetailId!: item
          else
            (item.productId ?? -item.hashCode): item,
      };
      final refundItems = <SaleItemDto>[];
      for (final line in selected) {
        SaleItemDto? match;
        if (line.saleDetailId != null) {
          match = saleItems[line.saleDetailId!];
        } else {
          for (final item in sale.items) {
            if (item.productId == line.productId) {
              match = item;
              break;
            }
          }
        }
        if (match == null) continue;
        refundItems.add(
          SaleItemDto(
            saleDetailId: match.saleDetailId,
            productId: match.productId,
            comboProductId: match.comboProductId,
            barcodeId: match.barcodeId,
            productName: match.productName,
            barcode: match.barcode,
            variantName: match.variantName,
            isVirtualCombo: match.isVirtualCombo,
            trackingType: match.trackingType,
            isSerialized: match.isSerialized,
            quantity: double.tryParse(line.quantity.text.trim()) ?? 0,
            unitPrice: match.unitPrice,
            discountPercent: match.discountPercent,
            discountAmount: match.discountAmount,
            lineTotal: match.lineTotal,
            sourceSaleDetailId: line.saleDetailId ?? match.sourceSaleDetailId,
            serialNumbers: match.serialNumbers,
            comboComponentTracking: match.comboComponentTracking,
          ),
        );
      }
      if (refundItems.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
                content: Text('Selected lines could not be prepared')),
          );
        return;
      }

      ref.read(posNotifierProvider.notifier).loadRefundExchangeSession(
            sale,
            refundItems,
          );
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PosPage()),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = _linkedSale;
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: Text(
          widget.mode == SaleReturnDocumentMode.refundInvoice
              ? 'New Refund Invoice'
              : 'New Sale Return',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.mode == SaleReturnDocumentMode.saleReturn) ...[
              _CustomerPicker(
                  enabled: sale == null,
                  customer: _customer,
                  onPicked: (c) => setState(() => _customer = c)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _invoiceCtrl,
              readOnly: widget.initialSaleId != null,
              decoration: InputDecoration(
                labelText: widget.mode == SaleReturnDocumentMode.refundInvoice
                    ? 'Invoice Number (required)'
                    : 'Invoice Number ${_customer == null ? '(required for walk-in)' : '(optional)'}',
                prefixIcon: const Icon(Icons.receipt_long_outlined),
                suffixIcon: widget.initialSaleId != null
                    ? const Icon(Icons.lock_outline_rounded)
                    : IconButton(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: _findInvoice,
                      ),
              ),
              onSubmitted:
                  widget.initialSaleId != null ? null : (_) => _findInvoice(),
            ),
            if (_linking) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
            if (_linkError != null) ...[
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    ErrorHandler.message(_linkError!),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (sale != null)
              Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_rounded),
                  title: Text(sale.saleNumber),
                  subtitle: Text([
                    if ((sale.customerName ?? '').isNotEmpty)
                      sale.customerName!,
                  ].where((e) => e.isNotEmpty).join(' · ')),
                  trailing: Text(sale.totalAmount.toStringAsFixed(2),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _hasLinkedReturnableLines
                  ? (widget.mode == SaleReturnDocumentMode.refundInvoice
                      ? 'Refundable Items'
                      : 'Returnable Items')
                  : 'Items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_hasLinkedReturnableLines) ...[
              ..._buildReturnableLines(context),
            ] else if (widget.mode == SaleReturnDocumentMode.refundInvoice) ...[
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Refund invoices are created from the selected sale. Load an invoice to continue.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ] else ...[
              ..._buildLines(context),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _lines.add(_RetLine())),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Item'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (widget.mode == SaleReturnDocumentMode.refundInvoice &&
                _hasLinkedReturnableLines) ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.tonalIcon(
                        onPressed: _openInSellScreen,
                        icon: const Icon(Icons.point_of_sale_rounded),
                        label: const Text('Open in Sell Screen'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.undo_rounded),
                        label: const Text('Create Refund Invoice'),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(
                    widget.mode == SaleReturnDocumentMode.refundInvoice
                        ? 'Create Refund Invoice'
                        : 'Save Return',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLines(BuildContext context) {
    Theme.of(context);
    // Defaults from linked sale if present
    final saleItems = (_linkedSale?.items ?? const <SaleItemDto>[]);
    final defaultPrices = <int, double>{
      for (final it in saleItems)
        if (it.productId != null) it.productId!: it.unitPrice,
    };
    return [
      for (int i = 0; i < _lines.length; i++)
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _LineProductPicker(
                    line: _lines[i], defaultPrices: defaultPrices),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lines[i].qty,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lines[i].price,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Unit Price',
                          prefixIcon: Icon(Icons.currency_rupee_rounded),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _lines.length == 1
                          ? null
                          : () => setState(() => _lines.removeAt(i)),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _configureTracking(_lines[i]),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: Text(
                      _lines[i].tracking == null
                          ? 'Configure Variation / Tracking'
                          : _lines[i].tracking!.summary(
                                double.tryParse(_lines[i].qty.text.trim()) ?? 0,
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildReturnableLines(BuildContext context) {
    final theme = Theme.of(context);
    return [
      for (final line in _returnableLines)
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: line.selected,
                  onChanged: (value) {
                    setState(() {
                      line.selected = value ?? false;
                      if (line.selected && line.quantity.text.trim().isEmpty) {
                        line.quantity.text =
                            line.maxQuantity.toStringAsFixed(2);
                      }
                      if (!line.selected) {
                        line.quantity.clear();
                      }
                    });
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.productName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Original Qty ${line.originalQuantity.toStringAsFixed(2)} • Available ${line.maxQuantity.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unit Price ${line.unitPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 112,
                  child: TextField(
                    controller: line.quantity,
                    enabled: line.selected,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Future<void> _configureTracking(_RetLine line) async {
    final product = line.product;
    if (product == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Select a product first')),
        );
      return;
    }
    final qty = double.tryParse(line.qty.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter quantity first')),
        );
      return;
    }
    final selection = await showInventoryTrackingSelector(
      context: context,
      ref: ref,
      productId: product.productId,
      productName: product.name,
      quantity: qty,
      mode: InventoryTrackingMode.receive,
      initialSelection: line.tracking,
    );
    if (selection != null && mounted) {
      setState(() => line.tracking = selection);
    }
  }
}

class _RetLine {
  InventoryListItem? product;
  InventoryTrackingSelection? tracking;
  final qty = TextEditingController();
  final price = TextEditingController();
  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

class _ReturnableLine {
  _ReturnableLine({
    this.saleDetailId,
    required this.productId,
    required this.productName,
    required this.originalQuantity,
    required this.maxQuantity,
    required this.unitPrice,
    this.barcodeId,
    this.selected = false,
    String? quantity,
  }) : quantity = TextEditingController(text: quantity);

  factory _ReturnableLine.fromJson(
    Map<String, dynamic> json, {
    bool selectAll = false,
  }) {
    final maxQuantity = (json['max_quantity'] as num?)?.toDouble() ?? 0;
    return _ReturnableLine(
      saleDetailId: (json['sale_detail_id'] as num?)?.toInt(),
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      productName: (json['product_name']?.toString() ?? '').trim().isEmpty
          ? 'Product'
          : json['product_name'].toString(),
      originalQuantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      maxQuantity: maxQuantity,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      barcodeId: (json['barcode_id'] as num?)?.toInt(),
      selected: selectAll,
      quantity: selectAll ? maxQuantity.toStringAsFixed(2) : null,
    );
  }

  final int? saleDetailId;
  final int productId;
  final String productName;
  final double originalQuantity;
  final double maxQuantity;
  final double unitPrice;
  final int? barcodeId;
  bool selected;
  final TextEditingController quantity;

  void dispose() {
    quantity.dispose();
  }
}

class _LineProductPicker extends ConsumerStatefulWidget {
  const _LineProductPicker({required this.line, required this.defaultPrices});
  final _RetLine line;
  final Map<int, double> defaultPrices;
  @override
  ConsumerState<_LineProductPicker> createState() => _LineProductPickerState();
}

class _LineProductPickerState extends ConsumerState<_LineProductPicker> {
  final _controller = TextEditingController();
  List<InventoryListItem> _suggestions = const [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final list =
          await ref.read(inventoryRepositoryProvider).searchProducts(q);
      if (!mounted) return;
      setState(() => _suggestions = list.take(8).toList());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Product',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => setState(() => _suggestions = const []),
                  ),
          ),
          onChanged: (v) => _search(v.trim()),
        ),
        const SizedBox(height: 6),
        if (_suggestions.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: _suggestions
                  .map((p) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(p.name),
                        subtitle: Text([
                          if ((p.variantName ?? '').isNotEmpty)
                            'Var: ${p.variantName}',
                          'Stock: ${p.stock.toStringAsFixed(2)}',
                          'Price: ${(p.price ?? 0).toStringAsFixed(2)}'
                        ].join('  ·  ')),
                        onTap: () {
                          setState(() {
                            widget.line.product = p;
                            widget.line.tracking = null;
                            _controller.text = p.name;
                            final defaultPrice =
                                widget.defaultPrices[p.productId] ??
                                    p.price ??
                                    0.0;
                            widget.line.price.text =
                                defaultPrice.toStringAsFixed(2);
                            _suggestions = const [];
                          });
                        },
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _CustomerPicker extends StatelessWidget {
  const _CustomerPicker({
    required this.customer,
    required this.onPicked,
    this.enabled = true,
  });
  final PosCustomerDto? customer;
  final void Function(PosCustomerDto? c) onPicked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final picked = await showDialog<PosCustomerDto>(
                context: context,
                builder: (_) => const CustomerSelectorDialog(),
              );
              if (picked != null) onPicked(picked);
            },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Customer (optional)',
          prefixIcon: Icon(Icons.person_search_rounded),
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                customer == null ? 'Walk in' : customer!.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              enabled
                  ? Icons.arrow_drop_down_rounded
                  : Icons.lock_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
