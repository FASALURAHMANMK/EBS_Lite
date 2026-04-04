import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';
import 'package:ebs_lite/shared/widgets/app_selection_dialog.dart';
import 'package:ebs_lite/shared/widgets/sales_action_password_dialog.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/locale_preferences.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/models.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../../../pos/controllers/pos_notifier.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../../pos/presentation/pages/pos_page.dart';
import '../../data/sales_repository.dart';
import '../widgets/document_line_editor_dialog.dart';
import '../widgets/professional_document_widgets.dart';
import 'b2b_invoice_form_page.dart';
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
  String? _documentNumberPreview;

  bool get _hasLinkedReturnableLines => _returnableLines.isNotEmpty;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDocumentNumberPreview);
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

  List<_RetLine> _activeManualLines() {
    return _lines.where((line) {
      final qty = double.tryParse(line.qty.text.trim()) ?? 0;
      final price = double.tryParse(line.price.text.trim()) ?? 0;
      return line.product != null && qty > 0 && price > 0;
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
      Future.microtask(
        () => _loadDocumentNumberPreview(locationId: sale.locationId),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _linkedSale = null;
        _replaceReturnableLines(const []);
        _linkError = error;
      });
      Future.microtask(_loadDocumentNumberPreview);
    } finally {
      if (mounted) {
        setState(() => _linking = false);
      }
    }
  }

  Future<void> _loadDocumentNumberPreview({int? locationId}) async {
    try {
      final preview = widget.mode == SaleReturnDocumentMode.refundInvoice
          ? await ref
              .read(salesRepositoryProvider)
              .getNextDocumentNumberPreview('sale', locationId: locationId)
          : await ref
              .read(salesRepositoryProvider)
              .getNextSaleReturnNumberPreview(locationId: locationId);
      if (!mounted) return;
      setState(() => _documentNumberPreview = preview);
    } catch (_) {
      // Best-effort preview only.
    }
  }

  Future<void> _findInvoice() async {
    final code = _invoiceCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _linking = true);
    try {
      final list = await ref.read(salesRepositoryProvider).getSalesHistory(
            saleNumber: code,
            transactionType: 'B2B',
          );
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
        // Without a selected party, the original invoice is mandatory.
        if (sale == null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text(
                  'Invoice number is required when no B2B party is selected'),
            ));
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

      if (sale.isB2B) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => B2BInvoiceFormPage(
              sale: sale,
              exchangeItems: refundItems,
            ),
          ),
        );
      } else {
        ref.read(posNotifierProvider.notifier).loadRefundExchangeSession(
              sale,
              refundItems,
            );
        if (!mounted) return;
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PosPage()),
          (route) => route.isFirst,
        );
      }
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
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final selectedLines = _selectedReturnableLines();
    final manualLines = _activeManualLines();
    final itemCount =
        _hasLinkedReturnableLines ? selectedLines.length : manualLines.length;
    final totalQty = _hasLinkedReturnableLines
        ? selectedLines.fold<double>(
            0,
            (sum, line) =>
                sum + (double.tryParse(line.quantity.text.trim()) ?? 0),
          )
        : manualLines.fold<double>(
            0,
            (sum, line) => sum + (double.tryParse(line.qty.text.trim()) ?? 0),
          );
    final totalAmount = _hasLinkedReturnableLines
        ? selectedLines.fold<double>(
            0,
            (sum, line) =>
                sum +
                ((double.tryParse(line.quantity.text.trim()) ?? 0) *
                    line.unitPrice),
          )
        : manualLines.fold<double>(
            0,
            (sum, line) =>
                sum +
                ((double.tryParse(line.qty.text.trim()) ?? 0) *
                    (double.tryParse(line.price.text.trim()) ?? 0)),
          );
    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: Text(
          widget.mode == SaleReturnDocumentMode.refundInvoice
              ? 'New Refund Invoice'
              : 'New B2B Return',
        ),
      ),
      body: SafeArea(
        child: isDesktop
            ? _buildDesktopBody(
                context,
                sale,
                itemCount,
                totalQty,
                totalAmount,
              )
            : _buildMobileBody(context, sale),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context, SaleDto? sale) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMobileDocumentCard(sale),
        const SizedBox(height: 12),
        if (widget.mode == SaleReturnDocumentMode.saleReturn) ...[
          _CustomerPicker(
            enabled: sale == null,
            customer: _customer,
            onPicked: (c) => setState(() => _customer = c),
          ),
          const SizedBox(height: 12),
        ],
        _buildInvoiceLookupField(),
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
        if (sale != null) ...[
          _buildLinkedSaleListTile(sale),
          const SizedBox(height: 12),
        ],
        _buildReasonField(),
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
        _buildPrimaryActions(),
      ],
    );
  }

  Widget _buildMobileDocumentCard(SaleDto? sale) {
    final documentLabel = widget.mode == SaleReturnDocumentMode.refundInvoice
        ? 'Refund Invoice Number'
        : 'Return Number';
    final documentNumber = (_documentNumberPreview ?? '').trim().isEmpty
        ? 'Auto-generated on save'
        : _documentNumberPreview!;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mode == SaleReturnDocumentMode.refundInvoice
                  ? 'Refund Invoice'
                  : 'B2B Return',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              documentLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              documentNumber,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (sale != null) ...[
              const SizedBox(height: 12),
              Text(
                'Reference Invoice',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                sale.saleNumber,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBody(
    BuildContext context,
    SaleDto? sale,
    int itemCount,
    double totalQty,
    double totalAmount,
  ) {
    const gap = 12.0;
    const summaryWidth = 320.0;
    const topRowHeight = 154.0;
    const infoRowHeight = 170.0;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildDesktopHeader(),
          if (_linking) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_linkError != null) ...[
            const SizedBox(height: gap),
            ProfessionalBanner(
              message: ErrorHandler.message(_linkError!),
              color: Theme.of(context).colorScheme.errorContainer,
            ),
          ],
          const SizedBox(height: gap),
          SizedBox(
            height: topRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildReferenceCard(sale)),
                const SizedBox(width: gap),
                SizedBox(
                    width: summaryWidth,
                    child: _buildSummaryRail(
                      itemCount: itemCount,
                      totalQty: totalQty,
                      totalAmount: totalAmount,
                      compact: true,
                    )),
              ],
            ),
          ),
          const SizedBox(height: gap),
          SizedBox(
            height: infoRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: _buildCustomerCardDesktop(sale)),
                const SizedBox(width: gap),
                Expanded(flex: 5, child: _buildReasonCard()),
                const SizedBox(width: gap),
                SizedBox(
                    width: summaryWidth, child: _buildSourceControlsCard()),
              ],
            ),
          ),
          const SizedBox(height: gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildDesktopItemsSection()),
                const SizedBox(width: gap),
                SizedBox(
                  width: summaryWidth,
                  child: _buildSummaryRail(
                    itemCount: itemCount,
                    totalQty: totalQty,
                    totalAmount: totalAmount,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return ProfessionalDocumentHeader(
      title: widget.mode == SaleReturnDocumentMode.refundInvoice
          ? 'Refund Invoice Workspace'
          : 'B2B Return Workspace',
      subtitle:
          'Desktop users get a document-style return console: source document controls at the top, reason capture in the middle, and a structured item workspace for precise refunds.',
      badges: [
        ProfessionalBadge(
          label: widget.mode == SaleReturnDocumentMode.refundInvoice
              ? 'Refund Invoice'
              : 'B2B Return',
        ),
        if (_linkedSale != null)
          const ProfessionalBadge(
            label: 'Linked Invoice',
            backgroundColor: Color(0xFFE8F3EC),
            foregroundColor: Color(0xFF255C35),
          ),
        if (_customer != null)
          ProfessionalBadge(
            label: _customer!.name,
            backgroundColor: const Color(0xFFEAF1F8),
            foregroundColor: const Color(0xFF23415F),
          ),
      ],
    );
  }

  Widget _buildInvoiceLookupField() {
    return TextField(
      controller: _invoiceCtrl,
      readOnly: widget.initialSaleId != null,
      decoration: InputDecoration(
        labelText: widget.mode == SaleReturnDocumentMode.refundInvoice
            ? 'Invoice Number (required)'
            : 'B2B Invoice Number ${_customer == null ? '(required when no party is selected)' : '(optional)'}',
        prefixIcon: const Icon(Icons.receipt_long_outlined),
        suffixIcon: widget.initialSaleId != null
            ? const Icon(Icons.lock_outline_rounded)
            : IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: _findInvoice,
              ),
      ),
      onSubmitted: widget.initialSaleId != null ? null : (_) => _findInvoice(),
    );
  }

  Widget _buildReasonField() {
    return TextField(
      controller: _reasonCtrl,
      decoration: const InputDecoration(
        labelText: 'Reason (required)',
        prefixIcon: Icon(Icons.description_outlined),
      ),
    );
  }

  Widget _buildLinkedSaleListTile(SaleDto sale) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.receipt_long_rounded),
        title: Text(sale.saleNumber),
        subtitle: Text([
          if ((sale.customerName ?? '').isNotEmpty) sale.customerName!,
        ].where((e) => e.isNotEmpty).join(' · ')),
        trailing: Text(
          sale.totalAmount.toStringAsFixed(2),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  Widget _buildReferenceCard(SaleDto? sale) {
    return ProfessionalOverviewCard(
      showHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              ProfessionalMetaCell(
                label: widget.mode == SaleReturnDocumentMode.refundInvoice
                    ? 'Refund Invoice Number'
                    : 'Return Number',
                value: (_documentNumberPreview ?? '').trim().isEmpty
                    ? 'Auto-generated on save'
                    : _documentNumberPreview!,
              ),
              ProfessionalMetaCell(
                label: 'Reference Invoice',
                value: sale?.saleNumber ?? 'Not linked',
              ),
              ProfessionalMetaCell(
                label: 'Invoice Date',
                value: sale?.saleDate == null
                    ? 'Pending'
                    : AppDateTime.formatFlexibleDate(
                        context,
                        ref.watch(localePreferencesProvider),
                        sale!.saleDate!.toIso8601String(),
                        fallback: sale.saleDate!.toString(),
                      ),
              ),
              ProfessionalMetaCell(
                label: 'Party',
                value: (sale?.customerName ?? '').trim().isEmpty
                    ? (_customer?.name ?? 'Not selected')
                    : sale!.customerName ?? 'Not selected',
              ),
              ProfessionalMetaCell(
                label: 'Invoice Total',
                value:
                    sale == null ? '0.00' : sale.totalAmount.toStringAsFixed(2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            sale == null
                ? 'Link an invoice to load returnable lines. For B2B returns, you can also work by party when a single source invoice can be inferred by the backend.'
                : 'The linked invoice controls which quantities remain refundable and keeps the document tied to the original commercial reference.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCardDesktop(SaleDto? sale) {
    return ProfessionalOverviewCard(
      title: 'Customer Information',
      icon: Icons.business_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mode == SaleReturnDocumentMode.saleReturn) ...[
            _CustomerPicker(
              enabled: sale == null,
              customer: _customer,
              onPicked: (c) => setState(() => _customer = c),
            ),
            const SizedBox(height: 12),
          ],
          ProfessionalFieldGrid(
            fields: [
              ProfessionalFieldGridItem(
                label: 'Selected Party',
                value: _customer?.name ?? sale?.customerName ?? '',
              ),
              ProfessionalFieldGridItem(
                label: 'Invoice Status',
                value: sale == null
                    ? 'Awaiting source invoice'
                    : (sale.status ?? 'Pending'),
              ),
              ProfessionalFieldGridItem(
                label: 'Workflow Rule',
                value: widget.mode == SaleReturnDocumentMode.refundInvoice
                    ? 'Refund invoices always require a linked invoice.'
                    : (_customer == null
                        ? 'Invoice is required when no party is selected.'
                        : 'Party-selected returns can defer invoice selection to the backend.'),
                maxLines: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard() {
    return ProfessionalSectionCard(
      title: 'Return Reason',
      subtitle:
          'Capture the operational reason clearly. The authorization step still happens on save.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _reasonCtrl,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Refunds and returns require the separate edit/refund password before submission.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceControlsCard() {
    return ProfessionalSectionCard(
      title: 'Source Controls',
      subtitle:
          'Load the invoice, then refine quantities or switch to the sell screen for exchange flows.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInvoiceLookupField(),
          if (_linkedSale != null) ...[
            const SizedBox(height: 12),
            _buildLinkedSaleListTile(_linkedSale!),
          ],
          if (widget.mode == SaleReturnDocumentMode.refundInvoice &&
              _hasLinkedReturnableLines) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openInSellScreen,
              icon: const Icon(Icons.point_of_sale_rounded),
              label: const Text('Open in Sell Screen'),
              style: professionalCompactButtonStyle(context, outlined: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopItemsSection() {
    final title = _hasLinkedReturnableLines
        ? (widget.mode == SaleReturnDocumentMode.refundInvoice
            ? 'Refundable Items'
            : 'Returnable Items')
        : 'Items';
    return ProfessionalSectionCard(
      title: title,
      subtitle: _hasLinkedReturnableLines
          ? 'Use the quantity column to control how much of each source line is being returned.'
          : (widget.mode == SaleReturnDocumentMode.refundInvoice
              ? 'Refund invoices can only be created from a linked sale.'
              : 'Add products manually when you are processing a return by party without first loading an invoice.'),
      action: !_hasLinkedReturnableLines &&
              widget.mode == SaleReturnDocumentMode.saleReturn
          ? FilledButton.tonalIcon(
              onPressed: () => setState(() => _lines.add(_RetLine())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item'),
              style: professionalCompactButtonStyle(context),
            )
          : null,
      expandChild: true,
      child: _hasLinkedReturnableLines
          ? Column(
              children: [
                const _ReturnableTableHeader(),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: _returnableLines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ReturnableTableRow(
                      line: _returnableLines[index],
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ),
              ],
            )
          : widget.mode == SaleReturnDocumentMode.refundInvoice
              ? const Center(
                  child: ProfessionalDocumentEmptyState(
                    title: 'Invoice Required',
                    message:
                        'Refund invoices are created from a linked sale. Load an invoice to continue.',
                    icon: Icons.receipt_long_outlined,
                  ),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ..._buildLines(context),
                    const SizedBox(height: 10),
                    Text(
                      'Manual return lines are used only when the backend can resolve a matching customer source document.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryRail({
    required int itemCount,
    required double totalQty,
    required double totalAmount,
    bool compact = false,
  }) {
    return ProfessionalSummaryCard(
      title: compact ? 'Selection Snapshot' : 'Return Summary',
      expandContent: !compact,
      rows: [
        (label: 'Items', value: '$itemCount', emphasize: false),
        (
          label: 'Total Qty',
          value: formatDocumentQuantity(totalQty),
          emphasize: false,
        ),
        (
          label: 'Mode',
          value: widget.mode == SaleReturnDocumentMode.refundInvoice
              ? 'Refund Invoice'
              : 'B2B Return',
          emphasize: false,
        ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8E4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Value',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  totalAmount.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFBA1A1A),
                      ),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            _buildPrimaryActions(compact: true),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryActions({bool compact = false}) {
    final primaryLabel = widget.mode == SaleReturnDocumentMode.refundInvoice
        ? 'Create Refund Invoice'
        : 'Save B2B Return';
    if (widget.mode == SaleReturnDocumentMode.refundInvoice &&
        _hasLinkedReturnableLines) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: compact ? 40 : 48,
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
              height: compact ? 40 : 48,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.undo_rounded),
                label: Text(primaryLabel),
              ),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      height: compact ? 40 : 48,
      child: FilledButton(
        onPressed: _save,
        child: Text(primaryLabel),
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

class _ReturnableTableHeader extends StatelessWidget {
  const _ReturnableTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          ProfessionalHeaderCell(
            label: 'Pick',
            flex: 5,
            textAlign: TextAlign.center,
          ),
          ProfessionalHeaderCell(label: 'Item', flex: 26),
          ProfessionalHeaderCell(
            label: 'Original',
            flex: 8,
            textAlign: TextAlign.right,
          ),
          ProfessionalHeaderCell(
            label: 'Available',
            flex: 8,
            textAlign: TextAlign.right,
          ),
          ProfessionalHeaderCell(
            label: 'Price',
            flex: 9,
            textAlign: TextAlign.right,
          ),
          ProfessionalHeaderCell(
            label: 'Value',
            flex: 9,
            textAlign: TextAlign.right,
          ),
          ProfessionalHeaderCell(
            label: 'Return Qty',
            flex: 11,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ReturnableTableRow extends StatelessWidget {
  const _ReturnableTableRow({
    required this.line,
    required this.onChanged,
  });

  final _ReturnableLine line;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedQty = double.tryParse(line.quantity.text.trim()) ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Checkbox(
              value: line.selected,
              onChanged: (value) {
                line.selected = value ?? false;
                if (line.selected && line.quantity.text.trim().isEmpty) {
                  line.quantity.text = line.maxQuantity.toStringAsFixed(2);
                }
                if (!line.selected) {
                  line.quantity.clear();
                }
                onChanged();
              },
            ),
          ),
          ProfessionalBodyCell(
            label: line.productName,
            secondary: line.saleDetailId == null
                ? 'Manual line'
                : 'Source line #${line.saleDetailId}',
            flex: 26,
            secondaryMaxLines: 2,
          ),
          ProfessionalBodyCell(
            label: line.originalQuantity.toStringAsFixed(2),
            flex: 8,
            textAlign: TextAlign.right,
          ),
          ProfessionalBodyCell(
            label: line.maxQuantity.toStringAsFixed(2),
            flex: 8,
            textAlign: TextAlign.right,
          ),
          ProfessionalBodyCell(
            label: line.unitPrice.toStringAsFixed(2),
            flex: 9,
            textAlign: TextAlign.right,
          ),
          ProfessionalBodyCell(
            label: (selectedQty * line.unitPrice).toStringAsFixed(2),
            flex: 9,
            emphasize: true,
            textAlign: TextAlign.right,
          ),
          Expanded(
            flex: 11,
            child: TextField(
              controller: line.quantity,
              enabled: line.selected,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'Qty',
                isDense: true,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
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

class _CustomerPicker extends ConsumerWidget {
  const _CustomerPicker({
    required this.customer,
    required this.onPicked,
    this.enabled = true,
  });
  final PosCustomerDto? customer;
  final void Function(PosCustomerDto? c) onPicked;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final picked = await showDialog<PosCustomerDto>(
                context: context,
                builder: (context) {
                  final repo = ref.read(posRepositoryProvider);
                  final controller = TextEditingController();
                  List<PosCustomerDto> results = const [];
                  bool loading = true;
                  bool kickoff = true;

                  return StatefulBuilder(
                    builder: (context, setStateDialog) {
                      Future<void> doSearch(String query) async {
                        loading = true;
                        setStateDialog(() {});
                        try {
                          results = await repo.searchCustomers(
                            query,
                            customerType: 'B2B',
                          );
                        } finally {
                          loading = false;
                          setStateDialog(() {});
                        }
                      }

                      if (kickoff) {
                        kickoff = false;
                        Future.microtask(() => doSearch(''));
                      }

                      return AppSelectionDialog(
                        title: 'Select B2B Party',
                        maxWidth: 460,
                        loading: loading,
                        searchField: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: 'Search parties',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search_rounded),
                              onPressed: () => doSearch(controller.text.trim()),
                            ),
                          ),
                          onChanged: (value) => doSearch(value.trim()),
                          onSubmitted: (value) => doSearch(value.trim()),
                        ),
                        body: results.isEmpty && !loading
                            ? const Center(child: Text('No B2B parties'))
                            : ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (context, index) {
                                  final item = results[index];
                                  return ListTile(
                                    title: Text(item.name),
                                    subtitle: Text(
                                      [
                                        if ((item.contactPerson ?? '')
                                            .isNotEmpty)
                                          item.contactPerson!,
                                        if ((item.phone ?? '').isNotEmpty)
                                          item.phone!,
                                      ].join(' • '),
                                    ),
                                    onTap: () =>
                                        Navigator.of(context).pop(item),
                                  );
                                },
                              ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: const Text('Cancel'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
              if (picked != null) onPicked(picked);
            },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'B2B Party (optional)',
          prefixIcon: Icon(Icons.business_rounded),
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                customer == null ? 'No B2B party selected' : customer!.name,
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
