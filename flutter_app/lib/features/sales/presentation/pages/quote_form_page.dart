import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../auth/controllers/auth_notifier.dart';
import '../../../customers/data/customer_repository.dart';
import '../../../customers/data/models.dart';
import '../../../dashboard/controllers/location_notifier.dart';
import '../../../dashboard/data/taxes_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../data/sales_repository.dart';
import '../widgets/document_line_editor_dialog.dart';
import '../widgets/professional_document_widgets.dart';
import 'sale_detail_page.dart';

class QuoteFormPage extends ConsumerStatefulWidget {
  const QuoteFormPage({super.key, this.quoteId});

  final int? quoteId;

  @override
  ConsumerState<QuoteFormPage> createState() => _QuoteFormPageState();
}

class _QuoteFormPageState extends ConsumerState<QuoteFormPage> {
  final _discountCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  final _linesScrollController = ScrollController();

  DocumentCustomerSnapshot? _customer;
  String _transactionType = 'B2B';
  DateTime? _validUntil;
  List<DocumentLineDraft> _lines = const [];
  bool _loading = false;
  String? _error;
  String? _info;
  bool _readOnly = false;
  int? _convertedSaleId;
  String? _quoteNumber;
  String? _quoteNumberPreview;
  DateTime? _quoteDate;
  final Map<int, DocumentTaxProfile> _taxProfilesById = {};

  bool get _isEdit => widget.quoteId != null;

  List<DocumentLineDraft> get _activeLines => _lines
      .where(
        (line) => line.hasProduct && line.unitPrice > 0 && line.quantity > 0,
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadQuote();
    } else {
      _quoteDate = DateTime.now();
      Future.microtask(_loadQuoteNumberPreview);
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    _linesScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final quote =
          await ref.read(salesRepositoryProvider).getQuote(widget.quoteId!);
      final status = quote['status']?.toString() ?? 'DRAFT';
      final convertedSaleId = (quote['converted_sale_id'] as num?)?.toInt();
      final readOnly = convertedSaleId != null || status == 'CONVERTED';
      final customerId = (quote['customer_id'] as num?)?.toInt() ??
          ((quote['customer'] as Map<String, dynamic>?)?['customer_id']
              as int?);
      DocumentCustomerSnapshot? customer;
      if (customerId != null && customerId > 0) {
        try {
          final fullCustomer = await ref
              .read(customerRepositoryProvider)
              .getCustomer(customerId);
          customer = DocumentCustomerSnapshot.fromCustomer(fullCustomer);
        } catch (_) {
          final customerMap = quote['customer'] as Map<String, dynamic>?;
          customer = customerMap == null
              ? null
              : DocumentCustomerSnapshot(
                  customerId: customerId,
                  name: customerMap['name']?.toString() ?? 'Customer',
                  customerType: _transactionType,
                );
        }
      }

      if (!mounted) return;
      setState(() {
        _convertedSaleId = convertedSaleId;
        _readOnly = readOnly;
        _quoteNumber = quote['quote_number']?.toString();
        _quoteDate = DateTime.tryParse(quote['quote_date']?.toString() ?? '');
        _transactionType =
            normalizeSaleTransactionType(quote['transaction_type']?.toString());
        _customer = customer;
        _validUntil = DateTime.tryParse(quote['valid_until']?.toString() ?? '');
        _discountCtrl.text =
            ((quote['discount_amount'] as num?)?.toDouble() ?? 0)
                .toStringAsFixed(2);
        _notesCtrl.text = quote['notes']?.toString() ?? '';
        _lines = (quote['items'] as List<dynamic>? ?? const [])
            .map((item) =>
                DocumentLineDraft.fromQuoteJson(item as Map<String, dynamic>))
            .where((item) => item.hasProduct)
            .toList(growable: false);
        _info = !_readOnly
            ? null
            : (_convertedSaleId == null
                ? 'This quote is read-only because it has already been converted.'
                : 'This quote is read-only because it has already been converted to sale #$_convertedSaleId.');
      });
      Future.microtask(_applyTaxProfilesToLines);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadQuoteNumberPreview() async {
    try {
      final preview =
          await ref.read(salesRepositoryProvider).getNextQuoteNumberPreview();
      if (!mounted) return;
      setState(() => _quoteNumberPreview = preview);
    } catch (_) {
      // Best-effort preview only.
    }
  }

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _validUntil = picked);
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
                  customerType: _transactionType,
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
              title: _transactionType == 'B2B'
                  ? 'Select B2B Party'
                  : 'Select Customer',
              maxWidth: 640,
              loading: loading,
              searchField: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: _transactionType == 'B2B'
                      ? 'Search parties by name, phone, or email'
                      : 'Search customers',
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (value) => runSearch(value.trim()),
                onSubmitted: (value) => runSearch(value.trim()),
              ),
              body: results.isEmpty && !loading
                  ? Center(
                      child: Text(
                        _transactionType == 'B2B'
                            ? 'No B2B parties found'
                            : 'No customers found',
                      ),
                    )
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
                            customer.creditBalance == 0
                                ? '0.00'
                                : customer.creditBalance.toStringAsFixed(2),
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

  Future<List<DocumentProductOption>> _searchProducts(String query) async {
    final products =
        await ref.read(posRepositoryProvider).searchProducts(query);
    return products.map(DocumentProductOption.fromPosProduct).toList();
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
        _lines.where((line) => (line.taxId ?? 0) > 0).toList(growable: false);
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

  Future<void> _editLine({DocumentLineDraft? line, int? index}) async {
    if (_readOnly) return;
    final result = await showDocumentLineEditorDialog(
      context: context,
      ref: ref,
      title: line == null ? 'Add Quote Item' : 'Edit Quote Item',
      initialLine: line?.copy() ?? DocumentLineDraft.empty(),
      searchProducts: _searchProducts,
      allowDelete: line != null,
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
      if (index == null) {
        _lines = [..._lines, saved];
      } else {
        final next = [..._lines];
        next[index] = saved;
        _lines = next;
      }
    });
  }

  Future<void> _submit() async {
    if (_readOnly) {
      setState(() => _error = 'This quote is read-only.');
      return;
    }
    final items = _activeLines;
    if (items.isEmpty) {
      setState(() => _error = 'Add at least one quote line.');
      return;
    }
    if (_transactionType == 'B2B' && _customer == null) {
      setState(() => _error = 'Select a B2B party for this quote.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(salesRepositoryProvider);
      final payloadItems =
          items.map((line) => line.toQuoteJson()).toList(growable: false);
      if (_isEdit) {
        await repo.updateQuote(
          widget.quoteId!,
          customerId: _customer?.customerId,
          clearCustomer: _customer == null,
          transactionType: _transactionType,
          notes: _notesCtrl.text.trim(),
          validUntil: _validUntil,
          discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
          items: payloadItems,
        );
      } else {
        await repo.createQuote(
          customerId: _customer?.customerId,
          transactionType: _transactionType,
          validUntil: _validUntil,
          discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
          notes: _notesCtrl.text.trim(),
          items: payloadItems,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);
    final location = ref.watch(locationNotifierProvider).selected;
    final user = ref.watch(authNotifierProvider).user;
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final lines = _activeLines;
    final subtotal = lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
    final taxTotal = lines.fold<double>(0, (sum, line) => sum + line.taxAmount);
    final totalQty = lines.fold<double>(0, (sum, line) => sum + line.quantity);
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    final total = subtotal + taxTotal - discount;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: Text(_isEdit ? 'Quote' : 'New Quote'),
      ),
      body: SafeArea(
        child: _loading && _isEdit
            ? const Center(child: CircularProgressIndicator())
            : (isDesktop
                ? _buildDesktopBody(
                    localePrefs,
                    location?.name,
                    user?.username,
                    lines,
                    subtotal,
                    taxTotal,
                    totalQty,
                    discount,
                    total,
                  )
                : _buildMobileBody(
                    localePrefs,
                    location?.name,
                    user?.username,
                    lines,
                    subtotal,
                    taxTotal,
                    totalQty,
                    discount,
                    total,
                  )),
      ),
    );
  }

  Widget _buildDesktopBody(
    LocalePreferencesState localePrefs,
    String? locationName,
    String? username,
    List<DocumentLineDraft> lines,
    double subtotal,
    double taxTotal,
    double totalQty,
    double discount,
    double total,
  ) {
    const gap = 12.0;
    const summaryWidth = 312.0;
    const topRowHeight = 186.0;
    const infoRowHeight = 216.0;
    final statusBanners = _buildStatusBanners();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (_loading) ...[
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (statusBanners != null) ...[
            if (_loading) const SizedBox(height: gap),
            statusBanners,
            const SizedBox(height: gap),
          ],
          SizedBox(
            height: topRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildMetadataCard(
                    localePrefs,
                    locationName,
                    username,
                    compactLayout: true,
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(width: summaryWidth, child: _buildAccountCard()),
              ],
            ),
          ),
          const SizedBox(height: gap),
          SizedBox(
            height: infoRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: _buildCustomerCard()),
                const SizedBox(width: gap),
                Expanded(flex: 5, child: _buildShippingCard()),
                const SizedBox(width: gap),
                SizedBox(
                  width: summaryWidth,
                  child: _buildCommercialCard(localePrefs, compactLayout: true),
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
                    desktopLayout: true,
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: summaryWidth,
                  child: _buildSummaryCard(
                    lines.length,
                    totalQty,
                    subtotal,
                    taxTotal,
                    discount,
                    total,
                    expandContent: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(
    LocalePreferencesState localePrefs,
    String? locationName,
    String? username,
    List<DocumentLineDraft> lines,
    double subtotal,
    double taxTotal,
    double totalQty,
    double discount,
    double total,
  ) {
    final statusBanners = _buildStatusBanners();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loading) ...[
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (statusBanners != null) ...[
          if (_loading) const SizedBox(height: 12),
          statusBanners,
          const SizedBox(height: 12),
        ],
        _buildMetadataCard(localePrefs, locationName, username),
        const SizedBox(height: 12),
        _buildCustomerCard(),
        const SizedBox(height: 12),
        _buildShippingCard(),
        const SizedBox(height: 12),
        _buildCommercialCard(localePrefs),
        const SizedBox(height: 12),
        _buildLinesCard(lines, totalQty),
        const SizedBox(height: 12),
        _buildNotesCard(),
        const SizedBox(height: 12),
        _buildAccountCard(),
        const SizedBox(height: 12),
        _buildSummaryCard(
          lines.length,
          totalQty,
          subtotal,
          taxTotal,
          discount,
          total,
        ),
      ],
    );
  }

  Widget? _buildStatusBanners() {
    if ((_error ?? '').isEmpty && (_info ?? '').isEmpty) return null;
    return Column(
      children: [
        if ((_error ?? '').isNotEmpty)
          ProfessionalBanner(
            message: _error!,
            color: Theme.of(context).colorScheme.errorContainer,
          ),
        if ((_error ?? '').isNotEmpty && (_info ?? '').isNotEmpty)
          const SizedBox(height: 10),
        if ((_info ?? '').isNotEmpty)
          ProfessionalBanner(
            message: _info!,
            color: const Color(0xFFE7F0FA),
          ),
      ],
    );
  }

  Widget _buildCustomerCard() {
    final customer = _customer;
    return ProfessionalOverviewCard(
      title: 'Customer Information',
      icon: Icons.business_rounded,
      action: FilledButton.tonalIcon(
        onPressed: (_loading || _readOnly) ? null : _pickCustomer,
        icon: const Icon(Icons.search_rounded),
        label: Text(customer == null ? 'Select' : 'Change'),
        style: professionalCompactButtonStyle(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfessionalFieldGrid(
            fields: [
              ProfessionalFieldGridItem(
                label: 'Company / Customer',
                value: customer?.name ??
                    (_transactionType == 'B2B'
                        ? 'Select a B2B party'
                        : 'Optional retail customer'),
              ),
              ProfessionalFieldGridItem(
                label: 'Customer Type',
                value: customer?.customerType ?? _transactionType,
              ),
              ProfessionalFieldGridItem(
                label: 'Tax ID',
                value: customer?.taxNumber ?? '',
              ),
              ProfessionalFieldGridItem(
                label: 'Contact',
                value: [
                  if ((customer?.contactPerson ?? '').trim().isNotEmpty)
                    customer!.contactPerson!.trim(),
                  if ((customer?.phone ?? '').trim().isNotEmpty)
                    customer!.phone!.trim(),
                  if ((customer?.email ?? '').trim().isNotEmpty)
                    customer!.email!.trim(),
                ].join(' • '),
                maxLines: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShippingCard() {
    final customer = _customer;
    return ProfessionalOverviewCard(
      title: 'Shipping Details',
      icon: Icons.local_shipping_outlined,
      child: ProfessionalFieldGrid(
        fields: [
          ProfessionalFieldGridItem(
            label: 'Shipping Address',
            value: customer == null
                ? ''
                : ((customer.shippingAddress ?? '').trim().isNotEmpty
                    ? customer.shippingAddress!.trim()
                    : customer.primaryAddress),
            maxLines: 2,
          ),
          ProfessionalFieldGridItem(
            label: 'Billing Address',
            value: customer == null
                ? ''
                : ((customer.address ?? '').trim().isEmpty
                    ? 'No billing address on file'
                    : customer.address!.trim()),
            maxLines: 2,
          ),
          ProfessionalFieldGridItem(
            label: 'Contact Person',
            value: customer?.contactPerson ?? '',
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(
    LocalePreferencesState localePrefs,
    String? locationName,
    String? username, {
    bool compactLayout = false,
  }) {
    final quoteDate = _quoteDate ?? DateTime.now();
    return ProfessionalOverviewCard(
      showHeader: false,
      expandChild: compactLayout,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              ProfessionalMetaCell(
                label: 'Quote Number',
                value: (_quoteNumber ?? '').trim().isEmpty
                    ? ((_quoteNumberPreview ?? '').trim().isEmpty
                        ? 'Auto-generated on save'
                        : _quoteNumberPreview!)
                    : _quoteNumber!,
              ),
              ProfessionalMetaCell(
                label: 'Quote Date',
                value: AppDateTime.formatDate(context, localePrefs, quoteDate),
              ),
              ProfessionalMetaCell(
                label: 'Location',
                value: (locationName ?? '').trim().isEmpty
                    ? 'No location selected'
                    : locationName!,
              ),
              ProfessionalMetaCell(
                label: 'Prepared By',
                value: (username ?? '').trim().isEmpty
                    ? 'Current user'
                    : username!,
              ),
              ProfessionalMetaCell(
                label: 'Valid Until',
                value: _validUntil == null
                    ? 'Not set'
                    : AppDateTime.formatDate(context, localePrefs, _validUntil),
              ),
            ],
          ),
          if (compactLayout) ...[
            const SizedBox(height: 14),
            Expanded(
              child: TextField(
                controller: _notesCtrl,
                enabled: !_readOnly,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: Theme.of(context).textTheme.bodySmall,
                decoration: InputDecoration(
                  hintText: 'Quote terms / internal notes',
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
            ),
          ] else if (_convertedSaleId != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SaleDetailPage(saleId: _convertedSaleId!),
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open Converted Sale'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommercialCard(
    LocalePreferencesState localePrefs, {
    bool compactLayout = false,
  }) {
    return ProfessionalSectionCard(
      title: 'Quote Controls',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _transactionType,
              decoration: const InputDecoration(
                labelText: 'Quote Type',
                prefixIcon: Icon(Icons.swap_horiz_rounded),
              ),
              onChanged: (_loading || _readOnly)
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _transactionType = value;
                        if (_customer != null &&
                            normalizeSaleTransactionType(
                                  _customer!.customerType,
                                ) !=
                                value) {
                          _customer = null;
                        }
                      });
                    },
              items: const [
                DropdownMenuItem(value: 'B2B', child: Text('B2B')),
                DropdownMenuItem(value: 'RETAIL', child: Text('Retail')),
              ],
            ),
            const SizedBox(height: 12),
            ProfessionalFieldPair(
              label: 'Valid Until',
              value: _validUntil == null
                  ? 'Not set'
                  : AppDateTime.formatDate(context, localePrefs, _validUntil),
              trailing: TextButton.icon(
                onPressed: (_loading || _readOnly) ? null : _pickValidUntil,
                icon: const Icon(Icons.event_rounded),
                label: Text(_validUntil == null ? 'Set' : 'Change'),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: compactLayout ? double.infinity : 168,
              child: TextField(
                controller: _discountCtrl,
                enabled: !_readOnly,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Header Discount',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.percent_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_convertedSaleId != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SaleDetailPage(saleId: _convertedSaleId!),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open Converted Sale'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLinesCard(
    List<DocumentLineDraft> lines,
    double totalQty, {
    bool desktopLayout = false,
  }) {
    return ProfessionalSectionCard(
      title: 'Quote Items',
      subtitle:
          'Tap a line to revise quantity, unit price, or discount with the shared document editor.',
      action: FilledButton.tonalIcon(
        onPressed: (_loading || _readOnly) ? null : () => _editLine(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
        style: professionalCompactButtonStyle(context),
      ),
      expandChild: desktopLayout,
      child: lines.isEmpty
          ? Center(
              child: ProfessionalDocumentEmptyState(
                title: _readOnly
                    ? 'No quote items available.'
                    : 'No items added yet.',
                message: _readOnly
                    ? 'This quote does not contain any active lines.'
                    : 'Use the shared item editor to search by barcode or product name and build the quote one line at a time.',
                actionLabel: (_loading || _readOnly) ? null : 'Add First Item',
                onAction: (_loading || _readOnly) ? null : () => _editLine(),
              ),
            )
          : desktopLayout
              ? Column(
                  children: [
                    const _QuoteTableHeader(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Scrollbar(
                        controller: _linesScrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _linesScrollController,
                          padding: EdgeInsets.zero,
                          itemCount: lines.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _QuoteTableRow(
                            index: index + 1,
                            line: lines[index],
                            enabled: !_readOnly,
                            onTap: () =>
                                _editLine(line: lines[index], index: index),
                            onDelete: _readOnly
                                ? null
                                : () => setState(
                                      () =>
                                          _lines = [..._lines]..removeAt(index),
                                    ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Items: ${lines.length}    Total Qty: ${formatDocumentQuantity(totalQty)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (var index = 0; index < lines.length; index++) ...[
                      _buildMobileLineCard(lines[index], index),
                      if (index != lines.length - 1) const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: (_loading || _readOnly)
                              ? null
                              : () => _editLine(),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Add New Item'),
                        ),
                        const Spacer(),
                        Text(
                          'Items: ${lines.length}    Total Qty: ${formatDocumentQuantity(totalQty)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Widget _buildMobileLineCard(DocumentLineDraft line, int index) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _readOnly ? null : () => _editLine(line: line, index: index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      line.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    line.lineGrandTotal.toStringAsFixed(2),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (line.supportingText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  line.supportingText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _MobileMetricChip(
                    label: 'Qty',
                    value: formatDocumentQuantity(line.quantity),
                  ),
                  _MobileMetricChip(
                    label: 'Price',
                    value: line.unitPrice.toStringAsFixed(2),
                  ),
                  _MobileMetricChip(
                    label: 'Disc %',
                    value: line.discountPercent.toStringAsFixed(2),
                  ),
                  _MobileMetricChip(
                    label: 'Tax',
                    value: line.taxAmount.toStringAsFixed(2),
                  ),
                ],
              ),
              if (!_readOnly) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _editLine(line: line, index: index),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _lines = [..._lines]..removeAt(index),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return ProfessionalSectionCard(
      title: 'Quote Notes',
      subtitle:
          'Use this space for commercial terms, delivery notes, or wording that should travel with the quote.',
      child: TextField(
        controller: _notesCtrl,
        enabled: !_readOnly,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Terms / Notes',
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    final customer = _customer;
    return ProfessionalSectionCard(
      title: 'Customer Exposure',
      child: customer == null
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfessionalAmountHighlight(value: '0.00'),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfessionalAmountHighlight(
                  value: customer.creditBalance.toStringAsFixed(2),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current outstanding balance',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                ProfessionalPreviewRow(
                  label: 'Credit Limit',
                  value: customer.creditLimit.toStringAsFixed(2),
                ),
                const SizedBox(height: 10),
                ProfessionalPreviewRow(
                  label: 'Payment Terms',
                  value: customer.paymentTerms > 0
                      ? '${customer.paymentTerms} days'
                      : 'Not set',
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(
    int itemCount,
    double totalQty,
    double subtotal,
    double taxTotal,
    double discount,
    double total, {
    bool expandContent = false,
  }) {
    return ProfessionalSummaryCard(
      title: 'Quote Summary',
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
          value: subtotal.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Tax',
          value: taxTotal.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Header Discount',
          value: discount.toStringAsFixed(2),
          emphasize: false,
        ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8E4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quoted Total',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  total.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFBA1A1A),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_loading || _readOnly) ? null : _submit,
            icon: const Icon(Icons.request_quote_rounded),
            label: Text(
              _readOnly
                  ? 'Read-only'
                  : (_isEdit ? 'Update Quote' : 'Create Quote'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteTableHeader extends StatelessWidget {
  const _QuoteTableHeader();

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
            label: '#',
            flex: 4,
            textAlign: TextAlign.center,
          ),
          ProfessionalHeaderCell(label: 'Barcode', flex: 9),
          ProfessionalHeaderCell(label: 'Item Details', flex: 28),
          ProfessionalHeaderCell(
            label: 'Qty',
            flex: 6,
            textAlign: TextAlign.center,
          ),
          ProfessionalHeaderCell(
            label: 'Price',
            flex: 8,
            textAlign: TextAlign.right,
          ),
          ProfessionalHeaderCell(
            label: 'Disc %',
            flex: 6,
            textAlign: TextAlign.right,
          ),
          ProfessionalHeaderCell(
            label: 'Tax',
            flex: 8,
            textAlign: TextAlign.right,
          ),
          ProfessionalHeaderCell(
            label: 'Total',
            flex: 9,
            textAlign: TextAlign.right,
          ),
          ProfessionalHeaderCell(
            label: 'Action',
            flex: 6,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QuoteTableRow extends StatelessWidget {
  const _QuoteTableRow({
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
              ProfessionalBodyCell(
                label: '$index',
                flex: 4,
                textAlign: TextAlign.center,
              ),
              ProfessionalBodyCell(
                label:
                    (line.barcode ?? '').trim().isEmpty ? '-' : line.barcode!,
                flex: 9,
              ),
              ProfessionalBodyCell(
                label: line.displayName,
                secondary: line.supportingText,
                secondaryMaxLines: 2,
                flex: 28,
              ),
              ProfessionalBodyCell(
                label: formatDocumentQuantity(line.quantity),
                flex: 6,
                textAlign: TextAlign.center,
              ),
              ProfessionalBodyCell(
                label: line.unitPrice.toStringAsFixed(2),
                flex: 8,
                textAlign: TextAlign.right,
              ),
              ProfessionalBodyCell(
                label: line.discountPercent.toStringAsFixed(2),
                flex: 6,
                textAlign: TextAlign.right,
              ),
              ProfessionalBodyCell(
                label: line.taxAmount.toStringAsFixed(2),
                secondary: line.taxLabel,
                flex: 8,
                textAlign: TextAlign.right,
              ),
              ProfessionalBodyCell(
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

class _MobileMetricChip extends StatelessWidget {
  const _MobileMetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
