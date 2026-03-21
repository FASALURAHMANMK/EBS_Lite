import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../data/customer_repository.dart';
import '../../data/models.dart';
import '../../data/warranty_models.dart';
import '../../data/warranty_repository.dart';
import 'warranty_detail_page.dart';

class CustomerWarrantyPage extends ConsumerStatefulWidget {
  const CustomerWarrantyPage({super.key});

  @override
  ConsumerState<CustomerWarrantyPage> createState() =>
      _CustomerWarrantyPageState();
}

class _CustomerWarrantyPageState extends ConsumerState<CustomerWarrantyPage> {
  final _saleNumber = TextEditingController();
  final _lookupSaleNumber = TextEditingController();
  final _lookupPhone = TextEditingController();
  final _walkInName = TextEditingController();
  final _walkInPhone = TextEditingController();
  final _walkInEmail = TextEditingController();
  final _walkInAddress = TextEditingController();
  final _notes = TextEditingController();

  bool _preparing = false;
  bool _saving = false;
  bool _searching = false;
  bool _searched = false;

  PrepareWarrantyResponseDto? _prepared;
  CustomerDto? _selectedCustomer;
  List<WarrantyRegistrationDto> _searchResults = const [];
  _WarrantyCustomerMode _customerMode = _WarrantyCustomerMode.walkIn;

  final Map<String, bool> _selectedItems = <String, bool>{};
  final Map<String, String> _selectedQuantities = <String, String>{};

  @override
  void dispose() {
    _saleNumber.dispose();
    _lookupSaleNumber.dispose();
    _lookupPhone.dispose();
    _walkInName.dispose();
    _walkInPhone.dispose();
    _walkInEmail.dispose();
    _walkInAddress.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _prepareWarranty() async {
    final saleNumber = _saleNumber.text.trim();
    if (saleNumber.isEmpty) {
      _showMessage('Enter an invoice number to load warranty-eligible items.');
      return;
    }
    setState(() => _preparing = true);
    try {
      final result = await ref
          .read(warrantyRepositoryProvider)
          .prepareWarranty(saleNumber);
      final defaults = <String, bool>{};
      final quantities = <String, String>{};
      for (final item in result.eligibleItems) {
        final key = _candidateKey(item);
        defaults[key] = !item.alreadyRegistered;
        quantities[key] = _fmtQty(item.quantity);
      }
      if (!mounted) return;
      setState(() {
        _prepared = result;
        _selectedItems
          ..clear()
          ..addAll(defaults);
        _selectedQuantities
          ..clear()
          ..addAll(quantities);
        _selectedCustomer = null;
        _customerMode = result.invoiceCustomer != null
            ? _WarrantyCustomerMode.invoice
            : _WarrantyCustomerMode.walkIn;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _searchWarranties() async {
    final saleNumber = _lookupSaleNumber.text.trim();
    final phone = _lookupPhone.text.trim();
    if (saleNumber.isEmpty && phone.isEmpty) {
      _showMessage('Enter an invoice number or mobile number to search.');
      return;
    }
    setState(() {
      _searching = true;
      _searched = true;
    });
    try {
      final results =
          await ref.read(warrantyRepositoryProvider).searchWarranties(
                saleNumber: saleNumber.isEmpty ? null : saleNumber,
                phone: phone.isEmpty ? null : phone,
              );
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (e) {
      if (!mounted) return;
      _showMessage(ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _submitWarranty() async {
    final prepared = _prepared;
    if (prepared == null) {
      _showMessage('Load an invoice before creating a warranty registration.');
      return;
    }

    final items = <CreateWarrantyItemPayload>[];
    for (final candidate in prepared.eligibleItems) {
      final key = _candidateKey(candidate);
      final selected = _selectedItems[key] ?? false;
      if (!selected || candidate.alreadyRegistered) continue;
      final rawQty = _selectedQuantities[key] ?? _fmtQty(candidate.quantity);
      final quantity =
          candidate.isSerialized ? 1.0 : (double.tryParse(rawQty.trim()) ?? -1);
      if (quantity <= 0 || quantity > candidate.quantity) {
        _showMessage(
          'Invalid quantity for ${candidate.productName}. Use a value between 0 and ${_fmtQty(candidate.quantity)}.',
        );
        return;
      }
      items.add(
        CreateWarrantyItemPayload(
          saleDetailId: candidate.saleDetailId,
          quantity: quantity,
          serialNumber: candidate.serialNumber,
          stockLotId: candidate.stockLotId,
        ),
      );
    }

    if (items.isEmpty) {
      _showMessage('Select at least one eligible item to register.');
      return;
    }

    int? customerId;
    String? customerName;
    String? customerPhone;
    String? customerEmail;
    String? customerAddress;

    switch (_customerMode) {
      case _WarrantyCustomerMode.invoice:
        final invoiceCustomer = prepared.invoiceCustomer;
        if (invoiceCustomer == null) {
          _showMessage('This invoice does not have a linked customer.');
          return;
        }
        customerId = invoiceCustomer.customerId;
        if (customerId == null) {
          customerName = invoiceCustomer.name;
          customerPhone = invoiceCustomer.phone;
          customerEmail = invoiceCustomer.email;
          customerAddress = invoiceCustomer.address;
        }
        break;
      case _WarrantyCustomerMode.existing:
        if (_selectedCustomer == null) {
          _showMessage('Select an existing customer before saving.');
          return;
        }
        customerId = _selectedCustomer!.customerId;
        break;
      case _WarrantyCustomerMode.walkIn:
        customerName = _walkInName.text.trim();
        customerPhone = _walkInPhone.text.trim();
        customerEmail =
            _walkInEmail.text.trim().isEmpty ? null : _walkInEmail.text.trim();
        customerAddress = _walkInAddress.text.trim().isEmpty
            ? null
            : _walkInAddress.text.trim();
        if (customerName.isEmpty || customerPhone.isEmpty) {
          _showMessage(
              'Walk-in registrations require customer name and phone.');
          return;
        }
        break;
    }

    setState(() => _saving = true);
    try {
      final created = await ref.read(warrantyRepositoryProvider).createWarranty(
            CreateWarrantyPayload(
              saleNumber: prepared.saleNumber,
              customerId: customerId,
              customerName: customerName,
              customerPhone: customerPhone,
              customerEmail: customerEmail,
              customerAddress: customerAddress,
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              items: items,
            ),
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WarrantyDetailPage(warrantyId: created.warrantyId),
        ),
      );
      await _prepareWarranty();
    } catch (e) {
      if (!mounted) return;
      _showMessage(ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<CustomerDto?> _pickExistingCustomer() async {
    final repo = ref.read(customerRepositoryProvider);
    List<CustomerDto> results = const [];
    bool loading = true;
    String? errorText;

    Future<void> load(StateSetter setInner, {String? query}) async {
      setInner(() {
        loading = true;
        errorText = null;
      });
      try {
        final customers = await repo.getCustomers(search: query);
        setInner(() => results = customers);
      } catch (e) {
        setInner(() => errorText = ErrorHandler.message(e));
      } finally {
        setInner(() => loading = false);
      }
    }

    if (!mounted) return null;
    return showDialog<CustomerDto>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) {
          if (loading && results.isEmpty && errorText == null) {
            // ignore: discarded_futures
            load(setInner);
          }
          return AppSelectionDialog(
            title: 'Select Customer',
            loading: loading,
            errorText: errorText,
            searchField: TextField(
              decoration: const InputDecoration(
                hintText: 'Search customers',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) {
                // ignore: discarded_futures
                load(setInner,
                    query: value.trim().isEmpty ? null : value.trim());
              },
            ),
            body: results.isEmpty && !loading
                ? const Center(child: Text('No customers found'))
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final customer = results[index];
                      final subtitle = [
                        if ((customer.phone ?? '').trim().isNotEmpty)
                          customer.phone!.trim(),
                        if ((customer.email ?? '').trim().isNotEmpty)
                          customer.email!.trim(),
                      ].join(' • ');
                      return ListTile(
                        title: Text(customer.name),
                        subtitle: subtitle.isEmpty ? null : Text(subtitle),
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
      ),
    );
  }

  Future<CustomerDto?> _createCustomerInline() async {
    if (!mounted) return null;
    return showModalBottomSheet<CustomerDto>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _QuickCustomerCreateSheet(),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _candidateKey(WarrantyCandidateDto item) {
    return [
      item.saleDetailId,
      item.productId,
      item.barcodeId ?? 0,
      item.serialNumber ?? '',
      item.stockLotId ?? 0,
      item.batchNumber ?? '',
    ].join(':');
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('dd MMM yyyy').format(value.toLocal());
  }

  String _fmtQty(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: isWide ? 104 : null,
          leading: isWide ? const DesktopSidebarToggleLeading() : null,
          title: const Text('Warranty Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Register Warranty'),
              Tab(text: 'Check Warranty'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _buildRegisterTab(),
              _buildSearchTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterTab() {
    final prepared = _prepared;
    final eligibleCount = prepared?.eligibleItems
            .where((item) => !item.alreadyRegistered)
            .length ??
        0;
    final existingCount = prepared?.existingWarranties.length ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Load Invoice',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _saleNumber,
                        decoration: const InputDecoration(
                          labelText: 'Invoice Number',
                          prefixIcon: Icon(Icons.receipt_long_rounded),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _prepareWarranty(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _preparing ? null : _prepareWarranty,
                      icon: _preparing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded),
                      label: const Text('Load'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (prepared == null)
          const AppEmptyView(
            title: 'No invoice loaded',
            message:
                'Search by invoice number to bring in warranty-enabled items, linked customer details, and existing registrations.',
            icon: Icons.verified_user_outlined,
          )
        else ...[
          _buildInvoiceSummary(prepared, eligibleCount, existingCount),
          const SizedBox(height: 16),
          _buildCustomerSection(prepared),
          const SizedBox(height: 16),
          _buildItemsSection(prepared),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Registration Notes',
              hintText:
                  'Optional service instructions or warranty registration remarks',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submitWarranty,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.verified_rounded),
              label: const Text('Create Warranty Registration'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Warranty Registrations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lookupSaleNumber,
                  decoration: const InputDecoration(
                    labelText: 'Invoice Number',
                    prefixIcon: Icon(Icons.receipt_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lookupPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Customer Mobile Number',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                  onSubmitted: (_) => _searchWarranties(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _searchWarranties,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded),
                    label: const Text('Search'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_searched && _searchResults.isEmpty && !_searching)
          const AppEmptyView(
            title: 'No warranties found',
            message:
                'Try a different invoice number or customer mobile number.',
            icon: Icons.manage_search_rounded,
          )
        else
          ..._searchResults.map(
            (warranty) => Card(
              elevation: 0,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  '${warranty.customerName} • ${warranty.saleNumber}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                subtitle: Text(
                  'Registered ${_fmtDate(warranty.registeredAt)} • ${warranty.items.length} item(s)'
                  '${(warranty.customerPhone ?? '').trim().isNotEmpty ? ' • ${warranty.customerPhone!.trim()}' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        WarrantyDetailPage(warrantyId: warranty.warrantyId),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInvoiceSummary(
    PrepareWarrantyResponseDto prepared,
    int eligibleCount,
    int existingCount,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice ${prepared.saleNumber}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip('Invoice Date', _fmtDate(prepared.saleDate)),
              _summaryChip('Eligible Items', '$eligibleCount'),
              _summaryChip('Existing Registrations', '$existingCount'),
              if (prepared.invoiceCustomer != null)
                _summaryChip(
                    'Invoice Customer', prepared.invoiceCustomer!.name),
            ],
          ),
          if (prepared.existingWarranties.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Existing Warranty Records',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...prepared.existingWarranties.map(
              (warranty) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Registration #${warranty.warrantyId} • ${warranty.customerName}',
                ),
                subtitle: Text(
                  'Registered ${_fmtDate(warranty.registeredAt)} • ${warranty.items.length} item(s)',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        WarrantyDetailPage(warrantyId: warranty.warrantyId),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerSection(PrepareWarrantyResponseDto prepared) {
    final invoiceCustomer = prepared.invoiceCustomer;
    final modes = <_WarrantyCustomerMode>[
      if (invoiceCustomer != null) _WarrantyCustomerMode.invoice,
      _WarrantyCustomerMode.existing,
      _WarrantyCustomerMode.walkIn,
    ];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Warranty Holder',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: modes
                  .map(
                    (mode) => ChoiceChip(
                      selected: _customerMode == mode,
                      label: Text(mode.label),
                      onSelected: (_) => setState(() => _customerMode = mode),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (_customerMode == _WarrantyCustomerMode.invoice &&
                invoiceCustomer != null)
              _customerInfoCard(
                title: 'Invoice Customer',
                name: invoiceCustomer.name,
                phone: invoiceCustomer.phone,
                email: invoiceCustomer.email,
                address: invoiceCustomer.address,
              ),
            if (_customerMode == _WarrantyCustomerMode.existing) ...[
              if (_selectedCustomer != null)
                _customerInfoCard(
                  title: 'Selected Customer',
                  name: _selectedCustomer!.name,
                  phone: _selectedCustomer!.phone,
                  email: _selectedCustomer!.email,
                  address: _selectedCustomer!.address,
                )
              else
                const Text('No customer selected yet.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _pickExistingCustomer();
                      if (picked == null || !mounted) return;
                      setState(() => _selectedCustomer = picked);
                    },
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Select Existing'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final created = await _createCustomerInline();
                      if (created == null || !mounted) return;
                      setState(() => _selectedCustomer = created);
                    },
                    icon: const Icon(Icons.person_add_alt_rounded),
                    label: const Text('Add Customer'),
                  ),
                ],
              ),
            ],
            if (_customerMode == _WarrantyCustomerMode.walkIn) ...[
              TextField(
                controller: _walkInName,
                decoration: const InputDecoration(labelText: 'Customer Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _walkInPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _walkInEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email Address (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _walkInAddress,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Address (optional)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(PrepareWarrantyResponseDto prepared) {
    final theme = Theme.of(context);
    final items = prepared.eligibleItems;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Warranty Items',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Serialized and batch details are pulled directly from the sold invoice records.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('This invoice has no warranty-enabled items.')
            else
              ...items.map(_buildCandidateTile),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateTile(WarrantyCandidateDto item) {
    final theme = Theme.of(context);
    final key = _candidateKey(item);
    final selected = _selectedItems[key] ?? false;
    final subtitleParts = <String>[
      if ((item.variantName ?? '').trim().isNotEmpty) item.variantName!.trim(),
      if ((item.barcode ?? '').trim().isNotEmpty)
        'Code ${item.barcode!.trim()}',
      if ((item.serialNumber ?? '').trim().isNotEmpty)
        'Serial ${item.serialNumber!.trim()}',
      if ((item.batchNumber ?? '').trim().isNotEmpty)
        'Batch ${item.batchNumber!.trim()}',
      if (item.batchExpiryDate != null)
        'Expiry ${_fmtDate(item.batchExpiryDate)}',
      'Coverage ${_fmtDate(item.warrantyStartDate)} to ${_fmtDate(item.warrantyEndDate)}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.alreadyRegistered
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.primary.withValues(alpha: 0.24),
        ),
        color: item.alreadyRegistered
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: item.alreadyRegistered ? true : selected,
            onChanged: item.alreadyRegistered
                ? null
                : (value) =>
                    setState(() => _selectedItems[key] = value ?? false),
            title: Text(
              item.productName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(subtitleParts.join('  •  ')),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip(
                'Tracking',
                item.isSerialized ? 'Serial' : item.trackingType,
              ),
              _summaryChip('Invoice Qty', _fmtQty(item.quantity)),
              _summaryChip(
                'Warranty',
                '${item.warrantyPeriodMonths} month(s)',
              ),
              if (item.alreadyRegistered)
                _summaryChip('Status', 'Already registered'),
            ],
          ),
          if (!item.isSerialized && !item.alreadyRegistered && selected) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey(
                'qty-$key-${_selectedQuantities[key] ?? _fmtQty(item.quantity)}',
              ),
              initialValue: _selectedQuantities[key] ?? _fmtQty(item.quantity),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Register Quantity',
                helperText:
                    'Maximum ${_fmtQty(item.quantity)} from this invoice allocation',
              ),
              onChanged: (value) => _selectedQuantities[key] = value.trim(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _customerInfoCard({
    required String title,
    required String name,
    String? phone,
    String? email,
    String? address,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if ((phone ?? '').trim().isNotEmpty) Text('Mobile: ${phone!.trim()}'),
          if ((email ?? '').trim().isNotEmpty) Text('Email: ${email!.trim()}'),
          if ((address ?? '').trim().isNotEmpty)
            Text('Address: ${address!.trim()}'),
        ],
      ),
    );
  }
}

enum _WarrantyCustomerMode {
  invoice('Invoice Customer'),
  existing('Existing Customer'),
  walkIn('Walk-in Customer');

  const _WarrantyCustomerMode(this.label);
  final String label;
}

class _QuickCustomerCreateSheet extends ConsumerStatefulWidget {
  const _QuickCustomerCreateSheet();

  @override
  ConsumerState<_QuickCustomerCreateSheet> createState() =>
      _QuickCustomerCreateSheetState();
}

class _QuickCustomerCreateSheetState
    extends ConsumerState<_QuickCustomerCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final customer = await ref
          .read(customerRepositoryProvider)
          .createCustomer(
            name: _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(customer);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Add Customer',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Customer Name'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email Address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Create Customer'),
            ),
          ],
        ),
      ),
    );
  }
}
