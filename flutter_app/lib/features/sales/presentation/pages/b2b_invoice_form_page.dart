import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/sales_action_password_dialog.dart';
import '../../../auth/controllers/auth_notifier.dart';
import '../../../customers/data/customer_repository.dart';
import '../../../customers/data/models.dart';
import '../../../dashboard/controllers/location_notifier.dart';
import '../../../dashboard/data/payment_methods_repository.dart';
import '../../../dashboard/data/taxes_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/models.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../data/sales_repository.dart';
import '../widgets/document_line_editor_dialog.dart';
import '../widgets/professional_document_widgets.dart';
import 'sale_detail_page.dart';

class B2BInvoiceFormPage extends ConsumerStatefulWidget {
  const B2BInvoiceFormPage({
    super.key,
    this.sale,
    this.exchangeItems = const [],
  });

  final SaleDto? sale;
  final List<SaleItemDto> exchangeItems;

  bool get isEdit => sale != null && exchangeItems.isEmpty;
  bool get isExchange => sale != null && exchangeItems.isNotEmpty;

  @override
  ConsumerState<B2BInvoiceFormPage> createState() => _B2BInvoiceFormPageState();
}

class _B2BInvoiceFormPageState extends ConsumerState<B2BInvoiceFormPage> {
  final _discountCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  final _itemsScrollController = ScrollController();

  DocumentCustomerSnapshot? _customer;
  PaymentMethodDto? _paymentMethod;
  List<DocumentLineDraft> _lines = const [];
  bool _saving = false;
  String? _error;
  String? _info;
  String? _invoiceNumberPreview;
  final Map<int, DocumentTaxProfile> _taxProfilesById = {};

  String get _title => widget.isEdit
      ? 'Edit B2B Invoice'
      : widget.isExchange
          ? 'B2B Exchange Invoice'
          : 'New B2B Invoice';

  List<DocumentLineDraft> get _activeLines => _lines
      .where(
          (line) => line.hasProduct && line.unitPrice > 0 && line.quantity != 0)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _hydrateFromSale();
    if (!widget.isEdit) {
      Future.microtask(_loadReceiptPreview);
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    _itemsScrollController.dispose();
    super.dispose();
  }

  void _hydrateFromSale() {
    final sale = widget.sale;
    if (sale == null) return;
    _discountCtrl.text = sale.discountAmount.toStringAsFixed(2);
    _paidCtrl.text = sale.paidAmount.toStringAsFixed(2);
    _notesCtrl.text = sale.notes ?? '';
    if (sale.paymentMethodId != null &&
        (sale.paymentMethodName ?? '').trim().isNotEmpty) {
      _paymentMethod = PaymentMethodDto(
        methodId: sale.paymentMethodId!,
        name: sale.paymentMethodName!,
        type: 'OTHER',
        isActive: true,
      );
    }
    if (widget.isEdit) {
      _lines = sale.items
          .where(
            (item) =>
                ((item.productId ?? 0) > 0 || (item.comboProductId ?? 0) > 0) &&
                item.quantity != 0,
          )
          .map(DocumentLineDraft.fromSaleItem)
          .toList(growable: false);
      Future.microtask(_applyTaxProfilesToLines);
      _info =
          'Editing ${sale.saleNumber} in the refreshed B2B document layout.';
    } else if (widget.isExchange) {
      _lines = widget.exchangeItems
          .map((item) => DocumentLineDraft.fromExchangeItem(sale, item))
          .toList(growable: false);
      Future.microtask(_applyTaxProfilesToLines);
      _paidCtrl.text = '0';
      _info =
          'Exchange draft for ${sale.saleNumber}. Refund and replacement lines stay in one business document.';
    }
    if (sale.customerId != null && sale.customerId! > 0) {
      Future.microtask(() async {
        try {
          final customer = await ref
              .read(customerRepositoryProvider)
              .getCustomer(sale.customerId!);
          if (!mounted) return;
          setState(() =>
              _customer = DocumentCustomerSnapshot.fromCustomer(customer));
        } catch (_) {
          if (!mounted) return;
          setState(
            () => _customer = DocumentCustomerSnapshot(
              customerId: sale.customerId,
              name: sale.customerName ?? 'B2B Customer',
              customerType: 'B2B',
            ),
          );
        }
      });
    }
  }

  Future<void> _loadReceiptPreview() async {
    try {
      final preview = await ref
          .read(salesRepositoryProvider)
          .getNextDocumentNumberPreview('sale');
      if (!mounted) return;
      setState(() => _invoiceNumberPreview = preview);
    } catch (_) {
      // Best-effort preview only.
    }
  }

  Future<CustomerDto?> _showCustomerDialog() async {
    return showDialog<CustomerDto>(
      context: context,
      builder: (context) {
        final repo = ref.read(customerRepositoryProvider);
        final controller = TextEditingController();
        List<CustomerDto> results = const [];
        bool loading = true;
        bool kickoff = true;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> runSearch(String query) async {
              loading = true;
              setStateDialog(() {});
              try {
                results = await repo.getCustomers(
                  search: query,
                  customerType: 'B2B',
                );
              } finally {
                loading = false;
                setStateDialog(() {});
              }
            }

            if (kickoff) {
              kickoff = false;
              Future.microtask(() => runSearch(''));
            }

            return AppSelectionDialog(
              title: 'Select B2B Party',
              maxWidth: 640,
              loading: loading,
              searchField: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Search parties by name, phone, or email',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => runSearch(value.trim()),
                onSubmitted: (value) => runSearch(value.trim()),
              ),
              body: results.isEmpty && !loading
                  ? const Center(child: Text('No B2B parties found'))
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = results[index];
                        final details = [
                          if ((customer.contactPerson ?? '').trim().isNotEmpty)
                            customer.contactPerson!.trim(),
                          if ((customer.phone ?? '').trim().isNotEmpty)
                            customer.phone!.trim(),
                          if ((customer.email ?? '').trim().isNotEmpty)
                            customer.email!.trim(),
                        ].join(' • ');
                        return ListTile(
                          title: Text(customer.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (details.isNotEmpty) Text(details),
                              Text(
                                (customer.shippingAddress ??
                                            customer.address ??
                                            'No address on profile')
                                        .trim()
                                        .isEmpty
                                    ? 'No address on profile'
                                    : (customer.shippingAddress ??
                                            customer.address ??
                                            'No address on profile')
                                        .trim(),
                              ),
                            ],
                          ),
                          trailing: Text(
                            customer.creditBalance.toStringAsFixed(2),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          onTap: () => Navigator.of(context).pop(customer),
                        );
                      },
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomer() async {
    final result = await _showCustomerDialog();
    if (result == null || !mounted) return;
    setState(() {
      _customer = DocumentCustomerSnapshot.fromCustomer(result);
      _error = null;
    });
  }

  Future<void> _pickPaymentMethod() async {
    final methods = await ref.read(posRepositoryProvider).getPaymentMethods();
    if (!mounted) return;
    final result = await showDialog<PaymentMethodDto>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        var filtered = methods;
        return StatefulBuilder(
          builder: (context, setStateDialog) => AppSelectionDialog(
            title: 'Payment Method',
            maxWidth: 520,
            loading: false,
            searchField: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Search payment methods',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) {
                setStateDialog(() {
                  final query = value.trim().toLowerCase();
                  filtered = query.isEmpty
                      ? methods
                      : methods
                          .where((method) =>
                              method.name.toLowerCase().contains(query) ||
                              method.type.toLowerCase().contains(query))
                          .toList();
                });
              },
            ),
            body: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final method = filtered[index];
                return ListTile(
                  title: Text(method.name),
                  subtitle: Text(method.type),
                  onTap: () => Navigator.of(context).pop(method),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && mounted) setState(() => _paymentMethod = result);
  }

  Future<List<DocumentProductOption>> _searchProducts(String query) async {
    final items = await ref
        .read(inventoryRepositoryProvider)
        .searchProducts(query, includeComboProducts: true);
    return items.map(DocumentProductOption.fromInventory).toList();
  }

  Future<Map<int, DocumentTaxProfile>> _loadTaxProfiles() async {
    if (_taxProfilesById.isNotEmpty) return _taxProfilesById;
    final taxes = await ref.read(taxesRepositoryProvider).getTaxes();
    _taxProfilesById.addEntries(
      taxes.map(
        (tax) => MapEntry(
          tax.taxId,
          DocumentTaxProfile(
            taxId: tax.taxId,
            name: tax.name,
            rate: tax.percentage,
          ),
        ),
      ),
    );
    return _taxProfilesById;
  }

  Future<DocumentTaxProfile?> _resolveTaxProfile(
    DocumentProductOption option,
  ) async {
    final inventoryRepo = ref.read(inventoryRepositoryProvider);
    int taxId = 0;
    if ((option.comboProductId ?? 0) > 0) {
      final combo = await inventoryRepo.getComboProduct(option.comboProductId!);
      taxId = combo.taxId;
    } else if ((option.productId ?? 0) > 0) {
      final product = await inventoryRepo.getProduct(option.productId!);
      taxId = product.taxId;
    }
    if (taxId <= 0) return null;
    final profiles = await _loadTaxProfiles();
    return profiles[taxId] ??
        DocumentTaxProfile(taxId: taxId, name: 'Tax', rate: 0);
  }

  Future<void> _applyTaxProfilesToLines() async {
    final linesToHydrate =
        _lines.where((line) => (line.taxId ?? 0) > 0).toList();
    if (linesToHydrate.isEmpty) return;
    final profiles = await _loadTaxProfiles();
    if (!mounted) return;
    setState(() {
      _lines = _lines.map((line) {
        final taxId = line.taxId;
        if ((taxId ?? 0) <= 0) return line;
        final profile = profiles[taxId!];
        if (profile == null) return line;
        final next = line.copy();
        final persistedAmount = next.persistedTaxAmount;
        next.applyTaxProfile(profile);
        next.persistedTaxAmount = persistedAmount;
        return next;
      }).toList(growable: false);
    });
  }

  Future<InventoryTrackingSelection?> _configureTrackingForLine(
    DocumentLineDraft draft,
  ) {
    if ((draft.productId ?? 0) <= 0) {
      return Future.value(null);
    }
    return showInventoryTrackingSelector(
      context: context,
      ref: ref,
      productId: draft.productId!,
      productName: draft.displayName,
      quantity: draft.quantity.abs(),
      mode: InventoryTrackingMode.issue,
      initialSelection: draft.tracking,
    );
  }

  Future<void> _editLine({DocumentLineDraft? line, int? index}) async {
    final result = await showDocumentLineEditorDialog(
      context: context,
      ref: ref,
      title: line == null ? 'Add Invoice Item' : 'Edit Invoice Item',
      initialLine: line?.copy() ?? DocumentLineDraft.empty(),
      searchProducts: _searchProducts,
      allowNegativeQuantity: true,
      allowDelete: line != null,
      configureTracking: _configureTrackingForLine,
      resolveTaxProfile: _resolveTaxProfile,
    );
    if (result == null || !mounted) return;
    setState(() {
      _error = null;
      if (result.remove) {
        if (index != null) {
          _lines = [..._lines]..removeAt(index);
        }
        return;
      }
      final saved = result.line!;
      final mergeIndex = _findMergeTarget(saved, excludeIndex: index);
      if (mergeIndex != null) {
        final next = [..._lines];
        final target = next[mergeIndex].copy();
        target.quantity += saved.quantity;
        target.persistedTaxAmount = (next[mergeIndex].persistedTaxAmount ??
                next[mergeIndex].taxAmount) +
            saved.taxAmount;
        next[mergeIndex] = target;
        if (index != null && index != mergeIndex) {
          next.removeAt(index);
        }
        _lines = next;
      } else if (index == null) {
        _lines = [..._lines, saved];
      } else {
        final next = [..._lines];
        next[index] = saved;
        _lines = next;
      }
    });
  }

  int? _findMergeTarget(DocumentLineDraft line, {int? excludeIndex}) {
    if (line.requiresTracking || line.tracking != null) return null;
    for (var i = 0; i < _lines.length; i++) {
      if (i == excludeIndex) continue;
      final current = _lines[i];
      if (current.requiresTracking || current.tracking != null) continue;
      final sameIdentity = (((current.barcodeId ?? 0) > 0) &&
              current.barcodeId == line.barcodeId) ||
          (((current.barcode ?? '').trim().isNotEmpty) &&
              current.barcode == line.barcode) ||
          (((current.productId ?? 0) > 0) &&
              current.productId == line.productId) ||
          (((current.comboProductId ?? 0) > 0) &&
              current.comboProductId == line.comboProductId);
      final sameCommercials = current.unitPrice == line.unitPrice &&
          current.discountPercent == line.discountPercent &&
          (current.taxId ?? 0) == (line.taxId ?? 0) &&
          current.quantity.sign == line.quantity.sign;
      if (sameIdentity && sameCommercials) return i;
    }
    return null;
  }

  Future<void> _submit() async {
    final customer = _customer;
    if (customer == null || (customer.customerId ?? 0) <= 0) {
      setState(() => _error = 'Select a B2B party before saving.');
      return;
    }
    final lines = _activeLines;
    if (lines.isEmpty) {
      setState(() => _error = 'Add at least one invoice line.');
      return;
    }
    if (lines.any((line) => line.requiresTracking && line.tracking == null)) {
      setState(() => _error = 'Configure tracking for all tracked items.');
      return;
    }
    final paidAmount = double.tryParse(_paidCtrl.text.trim()) ?? 0;
    if (paidAmount > 0 && _paymentMethod == null) {
      setState(
        () => _error = 'Select a payment method when a paid amount is entered.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.isEdit) {
        final salesActionPassword = await showSalesActionPasswordDialog(
          context,
          title: 'Authorize Invoice Edit',
          message:
              'Enter the separate edit/refund PIN or password configured for your user.',
          actionLabel: 'Authorize',
        );
        if (!mounted || salesActionPassword == null) return;
        final result = await ref.read(posRepositoryProvider).editSale(
              baseline: widget.sale!,
              transactionType: 'B2B',
              customerId: customer.customerId,
              items: lines.map((line) => line.toPosCartItem()).toList(),
              paymentMethodId: _paymentMethod?.methodId,
              paidAmount: paidAmount,
              discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
              notes: _notesCtrl.text.trim(),
              salesActionPassword: salesActionPassword,
            );
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SaleDetailPage(saleId: result.saleId),
          ),
        );
        return;
      }

      String? overridePassword;
      if (lines.any((line) => line.quantity < 0)) {
        overridePassword = await showSalesActionPasswordDialog(
          context,
          title: 'Authorize Refund Lines',
          message:
              'Enter the separate edit/refund PIN or password configured for your user.',
          actionLabel: 'Authorize',
        );
        if (!mounted || overridePassword == null) return;
      }

      final saleId = await ref.read(salesRepositoryProvider).createInvoice(
            customerId: customer.customerId!,
            items: lines.map((line) => line.toInvoiceJson()).toList(),
            paymentMethodId: _paymentMethod?.methodId,
            paidAmount: paidAmount,
            discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
            notes: _notesCtrl.text.trim(),
            transactionType: 'B2B',
            overridePassword: overridePassword,
          );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: saleId)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);
    final location = ref.watch(locationNotifierProvider).selected;
    final user = ref.watch(authNotifierProvider).user;
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final wide = MediaQuery.of(context).size.width >= 1200;
    const gap = 12.0;
    final sale = widget.sale;
    final lines = _activeLines;
    final lineNet = lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
    final computedTax =
        lines.fold<double>(0, (sum, line) => sum + line.taxAmount);
    final taxTotal = computedTax == 0 && (sale?.taxAmount ?? 0) > 0
        ? sale!.taxAmount
        : computedTax;
    final totalQty = lines.fold<double>(0, (sum, line) => sum + line.quantity);
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    final paid = double.tryParse(_paidCtrl.text.trim()) ?? 0;
    final total = lineNet + taxTotal - discount;
    final balance = total - paid;
    final statusBanners = _buildStatusBanners();
    final hasPaymentWarning = _paymentMethod == null && paid > 0;
    const desktopSummaryWidth = 312.0;
    const desktopTopRowHeight = 146.0;
    final desktopInfoRowHeight = hasPaymentWarning ? 176.0 : 156.0;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: Text(_title),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, _) {
            final summaryCard = _buildSummaryCard(
              lines.length,
              totalQty,
              lineNet,
              taxTotal,
              discount,
              paid,
              total,
              balance,
              expandContent: wide,
            );

            if (!wide) {
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (statusBanners != null) ...[
                    statusBanners,
                    const SizedBox(height: gap),
                  ],
                  _buildMetadataCard(
                    localePrefs,
                    location?.name,
                    user?.username,
                    sale?.saleDate,
                    sale?.saleNumber,
                  ),
                  const SizedBox(height: gap),
                  _buildCustomerCard(),
                  const SizedBox(height: gap),
                  _buildShippingCard(),
                  const SizedBox(height: gap),
                  _buildAccountCard(),
                  const SizedBox(height: gap),
                  _buildCommercialCard(),
                  const SizedBox(height: gap),
                  _buildLinesCard(lines, totalQty),
                  const SizedBox(height: gap),
                  summaryCard,
                ],
              );
            }

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (statusBanners != null) ...[
                    statusBanners,
                    const SizedBox(height: gap),
                  ],
                  SizedBox(
                    height: desktopTopRowHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildMetadataCard(
                            localePrefs,
                            location?.name,
                            user?.username,
                            sale?.saleDate,
                            sale?.saleNumber,
                            compactLayout: true,
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: desktopSummaryWidth,
                          child: _buildAccountCard(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: gap),
                  SizedBox(
                    height: desktopInfoRowHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 6, child: _buildCustomerCard()),
                        const SizedBox(width: gap),
                        Expanded(flex: 5, child: _buildShippingCard()),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: desktopSummaryWidth,
                          child: _buildCommercialCard(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: gap),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildLinesCard(
                            lines,
                            totalQty,
                            fillHeight: true,
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                            width: desktopSummaryWidth, child: summaryCard),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget? _buildStatusBanners() {
    if ((_error ?? '').isEmpty && (_info ?? '').isEmpty) return null;
    return Column(
      children: [
        if ((_error ?? '').isNotEmpty)
          _Banner(
            message: _error!,
            color: Theme.of(context).colorScheme.errorContainer,
          ),
        if ((_error ?? '').isNotEmpty && (_info ?? '').isNotEmpty)
          const SizedBox(height: 10),
        if ((_info ?? '').isNotEmpty)
          _Banner(message: _info!, color: const Color(0xFFE7F0FA)),
      ],
    );
  }

  Widget _buildCustomerCard() {
    final customer = _customer;
    return _InvoiceOverviewCard(
      title: 'Customer Information',
      icon: Icons.business_rounded,
      action: FilledButton.tonalIcon(
        onPressed: _saving ? null : _pickCustomer,
        icon: const Icon(Icons.search_rounded),
        label: Text(customer == null ? 'Select' : 'Change'),
        style: _compactButtonStyle(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldGrid(
            [
              (
                label: 'Company / Customer',
                value: customer?.name ?? '',
                maxLines: 1,
              ),
              (
                label: 'Tax ID',
                value: customer?.taxNumber ?? '',
                maxLines: 1,
              ),
              (
                label: 'Phone',
                value: customer?.phone ?? '',
                maxLines: 1,
              ),
              (
                label: 'Email',
                value: customer?.email ?? '',
                maxLines: 1,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldGrid(
    List<({String label, String value, int maxLines})> fields,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        final columns = constraints.maxWidth >= 360 ? 2 : 1;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 2,
          children: [
            for (final field in fields)
              SizedBox(
                width: itemWidth,
                child: _InvoiceFieldPair(
                  label: field.label,
                  value: field.value,
                  maxLines: field.maxLines,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildShippingCard() {
    final customer = _customer;
    return _InvoiceOverviewCard(
      title: 'Shipping Details',
      icon: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldGrid(
            [
              (
                label: 'Shipping Address',
                value: customer == null
                    ? ''
                    : ((customer.shippingAddress ?? '').trim().isNotEmpty
                        ? customer.shippingAddress!.trim()
                        : customer.primaryAddress),
                maxLines: 2,
              ),
              (
                label: 'Billing Address',
                value: customer == null
                    ? ''
                    : ((customer.address ?? '').trim().isEmpty
                        ? 'No billing address on file'
                        : customer.address!.trim()),
                maxLines: 2,
              ),
              (
                label: 'Contact Person',
                value: customer?.contactPerson ?? '',
                maxLines: 1,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(
    LocalePreferencesState localePrefs,
    String? locationName,
    String? username,
    DateTime? saleDate,
    String? saleNumber, {
    bool compactLayout = false,
  }) {
    final invoiceDate = saleDate ?? DateTime.now();
    final dueDate = (_customer?.paymentTerms ?? 0) > 0
        ? invoiceDate.add(Duration(days: _customer!.paymentTerms))
        : null;
    return _InvoiceOverviewCard(
      showHeader: false,
      expandChild: compactLayout,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _InvoiceMetaCell(
                label: 'Invoice Number',
                value: (saleNumber ?? '').trim().isEmpty
                    ? ((_invoiceNumberPreview ?? '').trim().isEmpty
                        ? 'Auto-generated on save'
                        : _invoiceNumberPreview!)
                    : saleNumber!,
              ),
              _InvoiceMetaCell(
                label: 'Invoice Date',
                value: AppDateTime.formatDate(
                  context,
                  localePrefs,
                  saleDate ?? DateTime.now(),
                ),
              ),
              _InvoiceMetaCell(
                label: 'Location',
                value: (locationName ?? '').trim().isEmpty
                    ? 'No location selected'
                    : locationName!,
              ),
              _InvoiceMetaCell(
                label: 'Prepared By',
                value: (username ?? '').trim().isEmpty
                    ? 'Current user'
                    : username!,
              ),
              _InvoiceMetaCell(
                label: 'Due Date',
                value: dueDate == null
                    ? 'Not set'
                    : AppDateTime.formatDate(
                        context,
                        localePrefs,
                        dueDate,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (compactLayout)
            Expanded(
              child: TextField(
                controller: _notesCtrl,
                enabled: !_saving,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: Theme.of(context).textTheme.bodySmall,
                decoration: InputDecoration(
                  hintText: 'Document Notes / Internal Remarks',
                  hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            )
          else
            TextField(
              controller: _notesCtrl,
              enabled: !_saving,
              minLines: 2,
              maxLines: 3,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                hintText: 'Document Notes / Internal Remarks',
                hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLinesCard(
    List<DocumentLineDraft> lines,
    double totalQty, {
    bool fillHeight = false,
  }) {
    return ProfessionalSectionCard(
      title: 'Invoice Items',
      action: FilledButton.tonalIcon(
        onPressed: _saving ? null : () => _editLine(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
        style: _compactButtonStyle(context),
      ),
      expandChild: fillHeight,
      child: lines.isEmpty
          ? Center(
              child: _InvoiceEmptyLines(
                onAdd: _saving ? null : () => _editLine(),
              ),
            )
          : Column(
              children: [
                const _InvoiceTableHeader(),
                const SizedBox(height: 10),
                if (fillHeight)
                  Expanded(
                    child: Scrollbar(
                      controller: _itemsScrollController,
                      thumbVisibility: true,
                      child: ListView.separated(
                        controller: _itemsScrollController,
                        padding: EdgeInsets.zero,
                        itemCount: lines.length,
                        itemBuilder: (context, index) => _InvoiceTableRow(
                          index: index + 1,
                          line: lines[index],
                          enabled: !_saving,
                          onTap: () =>
                              _editLine(line: lines[index], index: index),
                          onDelete: _saving
                              ? null
                              : () => setState(
                                    () => _lines = [..._lines]..removeAt(index),
                                  ),
                        ),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                      ),
                    ),
                  )
                else ...[
                  for (var index = 0; index < lines.length; index++) ...[
                    _InvoiceTableRow(
                      index: index + 1,
                      line: lines[index],
                      enabled: !_saving,
                      onTap: () => _editLine(line: lines[index], index: index),
                      onDelete: _saving
                          ? null
                          : () => setState(
                                () => _lines = [..._lines]..removeAt(index),
                              ),
                    ),
                    if (index != lines.length - 1) const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Items: ${lines.length}    Total Qty: ${formatDocumentQuantity(totalQty)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAccountCard() {
    final customer = _customer;
    return ProfessionalSectionCard(
      title: 'Credit Balance',
      child: customer == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _AccountAmount(value: '0.00'),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AccountAmount(
                  value: customer.creditBalance.toStringAsFixed(2),
                ),
                const SizedBox(height: 8),
                _PreviewRow(
                  label: 'Credit Limit',
                  value: customer.creditLimit.toStringAsFixed(2),
                ),
                const SizedBox(height: 8),
                _PreviewRow(
                  label: 'Payment Terms',
                  value: customer.paymentTerms > 0
                      ? '${customer.paymentTerms} days'
                      : 'Not set',
                ),
              ],
            ),
    );
  }

  Widget _buildCommercialCard() {
    return ProfessionalSectionCard(
      title: 'Payment & Discount',
      action: OutlinedButton.icon(
        onPressed: _saving ? null : _pickPaymentMethod,
        icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
        label: Text(_paymentMethod == null ? 'Select' : 'Change'),
        style: _compactButtonStyle(context, outlined: true),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InvoiceFieldPair(
            label: 'Payment Method',
            value: _paymentMethod?.name ?? '',
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AmountInputField(
                label: 'Paid',
                controller: _paidCtrl,
                enabled: !_saving,
                onChanged: (_) => setState(() {}),
              ),
              _AmountInputField(
                label: 'Discount',
                controller: _discountCtrl,
                enabled: !_saving,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          if (_paymentMethod == null &&
              (double.tryParse(_paidCtrl.text) ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Select a payment method when a paid amount is entered.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    int itemCount,
    double totalQty,
    double lineNet,
    double taxTotal,
    double discount,
    double paid,
    double total,
    double balance, {
    bool expandContent = false,
  }) {
    return ProfessionalSummaryCard(
      title: 'Document Summary',
      expandContent: expandContent,
      rows: [
        (label: 'Items', value: '$itemCount', emphasize: false),
        (
          label: 'Total Qty',
          value: formatDocumentQuantity(totalQty),
          emphasize: false,
        ),
        (
          label: 'Line Net',
          value: lineNet.toStringAsFixed(2),
          emphasize: false
        ),
        (
          label: 'Tax',
          value: taxTotal.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Discount',
          value: discount.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Paid Amount',
          value: paid.toStringAsFixed(2),
          emphasize: false
        ),
        (label: 'Balance', value: balance.toStringAsFixed(2), emphasize: true),
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
                  'Estimated Total',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  total.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFBA1A1A),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: Icon(
              widget.isEdit
                  ? Icons.save_as_rounded
                  : Icons.receipt_long_rounded,
            ),
            label: Text(
              _saving
                  ? 'Saving...'
                  : widget.isEdit
                      ? 'Save Invoice Changes'
                      : widget.isExchange
                          ? 'Create Exchange Invoice'
                          : 'Create B2B Invoice',
            ),
            style: _compactButtonStyle(context),
          ),
        ],
      ),
    );
  }
}

ButtonStyle _compactButtonStyle(
  BuildContext context, {
  bool outlined = false,
}) {
  final base = outlined
      ? OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 34),
          textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        )
      : FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 34),
          textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        );
  return base;
}

class _InvoiceOverviewCard extends StatelessWidget {
  const _InvoiceOverviewCard({
    this.title,
    this.icon,
    this.action,
    required this.child,
    this.showHeader = true,
    this.expandChild = false,
  });

  final String? title;
  final IconData? icon;
  final Widget? action;
  final Widget child;
  final bool showHeader;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 16),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            title ?? '',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(width: 10),
                    action!,
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (expandChild) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class _InvoiceFieldPair extends StatelessWidget {
  const _InvoiceFieldPair({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.trim().isEmpty ? 'Not set' : value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: value.trim().isEmpty
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceMetaCell extends StatelessWidget {
  const _InvoiceMetaCell({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTableHeader extends StatelessWidget {
  const _InvoiceTableHeader();

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
          _InvoiceHeaderCell(label: '#', flex: 4, textAlign: TextAlign.center),
          _InvoiceHeaderCell(label: 'Barcode', flex: 9),
          _InvoiceHeaderCell(label: 'Item Details', flex: 28),
          _InvoiceHeaderCell(
              label: 'Qty', flex: 6, textAlign: TextAlign.center),
          _InvoiceHeaderCell(
              label: 'Price', flex: 8, textAlign: TextAlign.right),
          _InvoiceHeaderCell(
              label: 'Disc %', flex: 6, textAlign: TextAlign.right),
          _InvoiceHeaderCell(label: 'Tax', flex: 8, textAlign: TextAlign.right),
          _InvoiceHeaderCell(
              label: 'Total', flex: 9, textAlign: TextAlign.right),
          _InvoiceHeaderCell(
              label: 'Action', flex: 6, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _InvoiceTableRow extends StatelessWidget {
  const _InvoiceTableRow({
    required this.index,
    required this.line,
    required this.enabled,
    required this.onTap,
    this.onDelete,
  });

  final int index;
  final DocumentLineDraft line;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              _InvoiceBodyCell(
                label: '$index',
                flex: 4,
                textAlign: TextAlign.center,
              ),
              _InvoiceBodyCell(
                label:
                    (line.barcode ?? '').trim().isEmpty ? '-' : line.barcode!,
                flex: 9,
              ),
              _InvoiceBodyCell(
                label: _itemPrimaryText(line),
                secondary: _itemSecondaryText(line),
                secondaryMaxLines: 2,
                flex: 28,
              ),
              _InvoiceBodyCell(
                label: formatDocumentQuantity(line.quantity),
                flex: 6,
                textAlign: TextAlign.center,
              ),
              _InvoiceBodyCell(
                label: line.unitPrice.toStringAsFixed(2),
                flex: 8,
                textAlign: TextAlign.right,
              ),
              _InvoiceBodyCell(
                label: line.discountPercent.toStringAsFixed(2),
                flex: 6,
                textAlign: TextAlign.right,
              ),
              _InvoiceBodyCell(
                label: line.taxAmount.toStringAsFixed(2),
                secondary: line.taxLabel,
                flex: 8,
                textAlign: TextAlign.right,
              ),
              _InvoiceBodyCell(
                label: line.lineGrandTotal.toStringAsFixed(2),
                flex: 9,
                emphasize: true,
                textAlign: TextAlign.right,
              ),
              Expanded(
                flex: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: enabled ? onTap : null,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceHeaderCell extends StatelessWidget {
  const _InvoiceHeaderCell({
    required this.label,
    required this.flex,
    this.textAlign = TextAlign.left,
  });

  final String label;
  final int flex;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
      ),
    );
  }
}

class _InvoiceBodyCell extends StatelessWidget {
  const _InvoiceBodyCell({
    required this.label,
    required this.flex,
    this.secondary,
    this.secondaryMaxLines = 1,
    this.emphasize = false,
    this.textAlign = TextAlign.left,
  });

  final String label;
  final int flex;
  final String? secondary;
  final int secondaryMaxLines;
  final bool emphasize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: textAlign == TextAlign.right
            ? CrossAxisAlignment.end
            : textAlign == TextAlign.center
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (emphasize
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.bodySmall)
                ?.copyWith(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if ((secondary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              secondary!,
              textAlign: textAlign,
              maxLines: secondaryMaxLines,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InvoiceEmptyLines extends StatelessWidget {
  const _InvoiceEmptyLines({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_rounded, size: 28),
          const SizedBox(height: 10),
          Text(
            'No invoice items added yet.',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add First Item'),
            style: _compactButtonStyle(context),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _AmountInputField extends StatelessWidget {
  const _AmountInputField({
    required this.label,
    required this.controller,
    required this.enabled,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          labelText: label,
          hintText: '0.00',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        onChanged: onChanged,
      ),
    );
  }
}

String _itemSecondaryText(DocumentLineDraft line) {
  final parts = <String>[
    if ((line.primaryStorage ?? '').trim().isNotEmpty)
      line.primaryStorage!.trim(),
    if ((line.variantName ?? '').trim().isNotEmpty)
      'Variation ${line.variantName!.trim()}',
    if (line.isSerialized)
      line.tracking == null
          ? 'Serials pending'
          : 'Serials ${line.tracking!.serialNumbers.length}/${line.quantity.abs().round()}',
    if (line.trackingType == 'BATCH')
      line.tracking == null ? 'Batch pending' : _batchSummary(line.tracking!),
  ];
  return parts.join(' • ');
}

String _itemPrimaryText(DocumentLineDraft line) {
  final name = (line.productName ?? '').trim();
  return name.isEmpty ? line.displayName : name;
}

String _batchSummary(InventoryTrackingSelection selection) {
  final batchNumber = (selection.batchNumber ?? '').trim();
  if (batchNumber.isNotEmpty) return 'Batch $batchNumber';
  final allocations = selection.batchAllocations.length;
  if (allocations > 0) return '$allocations batch(es)';
  return 'Batch set';
}

class _AccountAmount extends StatelessWidget {
  const _AccountAmount({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: const Color(0xFFBA1A1A),
          ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
