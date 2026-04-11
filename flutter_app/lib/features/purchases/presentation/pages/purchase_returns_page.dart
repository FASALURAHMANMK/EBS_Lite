import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/app_date_time.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/core/locale_preferences.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';
import 'package:ebs_lite/shared/widgets/professional_document_widgets.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/negative_stock_override.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../data/purchase_returns_repository.dart';
import '../../data/purchases_repository.dart';
import '../widgets/purchase_document_widgets.dart';
import 'purchase_return_detail_page.dart';

// Product picking (inventory)
import '../../../inventory/data/models.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';

class PurchaseReturnsPage extends ConsumerStatefulWidget {
  const PurchaseReturnsPage({super.key});

  @override
  ConsumerState<PurchaseReturnsPage> createState() =>
      _PurchaseReturnsPageState();
}

class _PurchaseReturnsPageState extends ConsumerState<PurchaseReturnsPage> {
  final _search = TextEditingController();
  bool _loading = true;
  bool _detailLoading = false;
  List<Map<String, dynamic>> _all = const [];
  Map<String, dynamic>? _selectedReturnDoc;
  Object? _detailError;
  int? _selectedReturnId;
  int _detailToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int? preferredReturnId}) async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(purchaseReturnsRepositoryProvider);
      final list = await repo.getReturns();
      if (!mounted) return;
      setState(() => _all = list);
      await _syncSelection(
        _filteredReturns(list),
        preferredReturnId: preferredReturnId,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filteredReturns(
      [List<Map<String, dynamic>>? rows]) {
    final source = rows ?? _all;
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source
        .where((e) =>
            (e['return_number'] ?? '').toString().toLowerCase().contains(q) ||
            (e['supplier']?['name'] ?? e['supplier_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q))
        .toList(growable: false);
  }

  Future<void> _syncSelection(
    List<Map<String, dynamic>> filtered, {
    int? preferredReturnId,
  }) async {
    if (!AppBreakpoints.isDesktop(context)) return;
    if (filtered.isEmpty) {
      if (!mounted) return;
      setState(() {
        _selectedReturnId = null;
        _selectedReturnDoc = null;
        _detailError = null;
        _detailLoading = false;
      });
      return;
    }
    final preferredMatch = preferredReturnId == null
        ? const <Map<String, dynamic>>[]
        : filtered
            .where((row) => row['return_id'] == preferredReturnId)
            .toList(growable: false);
    final selectedMatch = filtered
        .where((row) => row['return_id'] == _selectedReturnId)
        .toList(growable: false);
    final nextId = preferredMatch.isNotEmpty
        ? preferredMatch.first['return_id'] as int?
        : selectedMatch.isNotEmpty
            ? selectedMatch.first['return_id'] as int?
            : filtered.first['return_id'] as int?;
    if (nextId != null && nextId != _selectedReturnId) {
      await _selectReturn(nextId);
    }
  }

  Future<void> _selectReturn(int returnId) async {
    final token = ++_detailToken;
    setState(() {
      _selectedReturnId = returnId;
      _selectedReturnDoc = null;
      _detailError = null;
      _detailLoading = true;
    });
    try {
      final doc =
          await ref.read(purchaseReturnsRepositoryProvider).getReturn(returnId);
      if (!mounted || token != _detailToken) return;
      setState(() {
        _selectedReturnDoc = doc;
        _detailLoading = false;
      });
    } catch (error) {
      if (!mounted || token != _detailToken) return;
      setState(() {
        _detailError = error;
        _detailLoading = false;
      });
    }
  }

  Future<void> _openReturnDetail(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PurchaseReturnDetailPage(returnId: id)),
    );
    await _load(preferredReturnId: id);
  }

  Future<void> _openCreateReturn({required bool isDesktop}) async {
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const _ReturnFormPage()),
    );
    if (id == null) return;
    if (_search.text.trim().isNotEmpty) {
      setState(_search.clear);
    }
    await _load(preferredReturnId: id);
    if (!mounted) return;
    if (isDesktop) {
      await _selectReturn(id);
      return;
    }
    await _openReturnDetail(id);
  }

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final filtered = _filteredReturns();
    if (isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncSelection(filtered);
        }
      });
    }
    final linkedCount = filtered
        .where(
          (row) => (row['purchase']?['purchase_number'] ?? '')
              .toString()
              .trim()
              .isNotEmpty,
        )
        .length;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Purchase Returns'),
        actions: [
          IconButton(
            tooltip: 'New Return',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openCreateReturn(isDesktop: isDesktop),
          ),
          const SizedBox(width: 4)
        ],
      ),
      body: SafeArea(
        child: isDesktop
            ? _buildDesktopBody(filtered, linkedCount, localePrefs)
            : _buildMobileBody(filtered),
      ),
    );
  }

  Widget _buildDesktopBody(
    List<Map<String, dynamic>> filtered,
    int linkedCount,
    LocalePreferencesState localePrefs,
  ) {
    const gap = 12.0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ProfessionalDocumentHeader(
            title: 'Purchase Return Workbench',
            subtitle:
                'Desktop users get a denser return queue with source-purchase visibility and a live review pane.',
            badges: [
              ProfessionalBadge(label: '${filtered.length} Visible'),
              ProfessionalBadge(
                label: '$linkedCount Linked',
                backgroundColor: const Color(0xFFEAF1F8),
                foregroundColor: const Color(0xFF23415F),
              ),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            children: [
              Expanded(child: _buildReturnToolbar()),
              const SizedBox(width: gap),
              SizedBox(
                width: 220,
                child: FilledButton.icon(
                  onPressed: () => _openCreateReturn(isDesktop: true),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Return'),
                  style: professionalCompactButtonStyle(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: gap),
          Row(
            children: [
              Expanded(
                child: PurchaseDocumentMetricCard(
                  label: 'Visible Returns',
                  value: '${filtered.length}',
                  subtitle: 'Current search result',
                  icon: Icons.assignment_return_outlined,
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: PurchaseDocumentMetricCard(
                  label: 'Linked Source POs',
                  value: '$linkedCount',
                  subtitle: 'Returns with explicit source purchase',
                  icon: Icons.description_outlined,
                  tint: const Color(0xFFEAF1F8),
                  foreground: const Color(0xFF23415F),
                ),
              ),
            ],
          ),
          const SizedBox(height: gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: ProfessionalSectionCard(
                    title: 'Purchase Returns',
                    subtitle:
                        'Select a posted return to preview supplier context, source purchase, and returned lines.',
                    expandChild: true,
                    child: filtered.isEmpty
                        ? AppEmptyView(
                            title: 'No purchase returns',
                            message:
                                'Create a return or adjust the search to review recorded purchase returns.',
                            onRetry: () => _load(),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final pr = filtered[index];
                              final id = pr['return_id'] as int?;
                              final hasSource =
                                  (pr['purchase']?['purchase_number'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty;
                              return PurchaseDocumentListCard(
                                title: pr['return_number']?.toString() ??
                                    'Purchase Return',
                                subtitle: [
                                  if ((pr['supplier']?['name'] ??
                                          pr['supplier_name'] ??
                                          '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                                    (pr['supplier']?['name'] ??
                                            pr['supplier_name'])
                                        .toString(),
                                  if (pr['return_date'] != null)
                                    pr['return_date'].toString(),
                                  if (hasSource)
                                    'From ${pr['purchase']['purchase_number']}',
                                ].join(' • '),
                                selected: id == _selectedReturnId,
                                badges: [
                                  const ProfessionalBadge(
                                    label: 'Return Posted',
                                    backgroundColor: Color(0xFFFFF1D6),
                                    foregroundColor: Color(0xFF8A5200),
                                  ),
                                  if (hasSource)
                                    const ProfessionalBadge(
                                      label: 'Source Linked',
                                      backgroundColor: Color(0xFFEAF1F8),
                                      foregroundColor: Color(0xFF23415F),
                                    ),
                                ],
                                trailing: IconButton(
                                  tooltip: 'Open detail',
                                  onPressed: id == null
                                      ? null
                                      : () => _openReturnDetail(id),
                                  icon: const Icon(Icons.open_in_new_rounded),
                                ),
                                onTap:
                                    id == null ? null : () => _selectReturn(id),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  flex: 4,
                  child: _buildReturnPreview(localePrefs),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(List<Map<String, dynamic>> filtered) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfessionalDocumentHeader(
          title: 'Purchase Returns',
          subtitle:
              'Mobile keeps return review stacked, with supplier and source-purchase context visible on every card.',
          badges: [
            ProfessionalBadge(label: '${filtered.length} Visible'),
          ],
        ),
        const SizedBox(height: 12),
        _buildReturnToolbar(),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _openCreateReturn(isDesktop: false),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Return'),
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (filtered.isEmpty)
          AppEmptyView(
            title: 'No purchase returns',
            message:
                'Create a return or adjust the search to review recorded purchase returns.',
            onRetry: () => _load(),
          )
        else
          for (final pr in filtered) ...[
            PurchaseDocumentListCard(
              title: pr['return_number']?.toString() ?? 'Purchase Return',
              subtitle: [
                if ((pr['supplier']?['name'] ?? pr['supplier_name'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty)
                  (pr['supplier']?['name'] ?? pr['supplier_name']).toString(),
                if (pr['return_date'] != null) pr['return_date'].toString(),
                if ((pr['purchase']?['purchase_number'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty)
                  'From ${pr['purchase']['purchase_number']}',
              ].join(' • '),
              badges: [
                const ProfessionalBadge(
                  label: 'Return Posted',
                  backgroundColor: Color(0xFFFFF1D6),
                  foregroundColor: Color(0xFF8A5200),
                ),
                if ((pr['purchase']?['purchase_number'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty)
                  const ProfessionalBadge(
                    label: 'Source Linked',
                    backgroundColor: Color(0xFFEAF1F8),
                    foregroundColor: Color(0xFF23415F),
                  ),
              ],
              onTap: () async {
                final id = pr['return_id'] as int?;
                if (id == null) return;
                await _openReturnDetail(id);
              },
            ),
            if (pr != filtered.last) const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildReturnPreview(LocalePreferencesState localePrefs) {
    if (_detailLoading) {
      return const ProfessionalSectionCard(
        title: 'Return Preview',
        expandChild: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_detailError != null) {
      return ProfessionalSectionCard(
        title: 'Return Preview',
        child: AppEmptyView(
          title: 'Preview unavailable',
          message: ErrorHandler.message(_detailError!),
          onRetry: () {
            final returnId = _selectedReturnId;
            if (returnId != null) {
              _selectReturn(returnId);
            }
          },
        ),
      );
    }
    final doc = _selectedReturnDoc;
    if (doc == null) {
      return const ProfessionalSectionCard(
        title: 'Return Preview',
        child: ProfessionalDocumentEmptyState(
          title: 'Select a purchase return',
          message:
              'Choose a posted return from the left pane to review supplier context and returned lines.',
        ),
      );
    }

    final items =
        (doc['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    final totalQty = items.fold<double>(
      0,
      (sum, item) => sum + ((item['quantity'] as num?)?.toDouble() ?? 0),
    );
    final totalValue = items.fold<double>(
      0,
      (sum, item) =>
          sum +
          (((item['quantity'] as num?)?.toDouble() ?? 0) *
              ((item['unit_price'] as num?)?.toDouble() ?? 0)),
    );
    final sourcePurchase =
        (doc['purchase']?['purchase_number'] ?? '').toString().trim();
    return Column(
      children: [
        ProfessionalDocumentHeader(
          title: doc['return_number']?.toString() ?? 'Purchase Return',
          subtitle:
              'Preview supplier context, source purchase linkage, and returned lines before opening the full document.',
          badges: [
            const ProfessionalBadge(
              label: 'Return Posted',
              backgroundColor: Color(0xFFFFF1D6),
              foregroundColor: Color(0xFF8A5200),
            ),
            if ((doc['supplier']?['name'] ?? '').toString().trim().isNotEmpty)
              ProfessionalBadge(label: doc['supplier']['name'].toString()),
            if (sourcePurchase.isNotEmpty)
              const ProfessionalBadge(
                label: 'Source Linked',
                backgroundColor: Color(0xFFEAF1F8),
                foregroundColor: Color(0xFF23415F),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    ProfessionalOverviewCard(
                      title: 'Overview',
                      icon: Icons.assignment_return_rounded,
                      child: ProfessionalFieldGrid(
                        fields: [
                          ProfessionalFieldGridItem(
                            label: 'Supplier',
                            value: (doc['supplier']?['name'] ?? '')
                                    .toString()
                                    .trim()
                                    .isEmpty
                                ? 'Not available'
                                : doc['supplier']['name'].toString(),
                          ),
                          ProfessionalFieldGridItem(
                            label: 'Return Date',
                            value: AppDateTime.formatFlexibleDate(
                              context,
                              localePrefs,
                              doc['return_date']?.toString(),
                              fallback: doc['return_date']?.toString() ??
                                  'Not available',
                            ),
                          ),
                          ProfessionalFieldGridItem(
                            label: 'Source Purchase',
                            value: sourcePurchase.isEmpty
                                ? 'Not set'
                                : sourcePurchase,
                          ),
                          ProfessionalFieldGridItem(
                            label: 'Reason',
                            value:
                                (doc['reason'] ?? '').toString().trim().isEmpty
                                    ? 'No reason recorded'
                                    : doc['reason'].toString(),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ProfessionalSectionCard(
                        title: 'Line Snapshot',
                        subtitle:
                            'The first few returned lines stay visible for quick purchasing and warehouse review.',
                        expandChild: true,
                        child: items.isEmpty
                            ? const ProfessionalDocumentEmptyState(
                                title: 'No returned items',
                                message:
                                    'This return does not contain line items.',
                              )
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: items.length > 5 ? 5 : items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return PurchaseDocumentListCard(
                                    title:
                                        item['product']?['name']?.toString() ??
                                            'Product #${item['product_id']}',
                                    subtitle:
                                        'Qty ${((item['quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} • Unit ${((item['unit_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                    badges: const [],
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: ProfessionalSummaryCard(
                  title: 'Return Summary',
                  expandContent: true,
                  rows: [
                    (
                      label: 'Item Count',
                      value: '${items.length}',
                      emphasize: false,
                    ),
                    (
                      label: 'Total Qty',
                      value: totalQty.toStringAsFixed(2),
                      emphasize: false,
                    ),
                    (
                      label: 'Estimated Value',
                      value: totalValue.toStringAsFixed(2),
                      emphasize: true,
                    ),
                  ],
                  footer: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _selectedReturnId == null
                            ? null
                            : () => _openReturnDetail(_selectedReturnId!),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open Full Detail'),
                        style: professionalCompactButtonStyle(
                          context,
                          outlined: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReturnToolbar() {
    return ProfessionalSectionCard(
      title: 'Filters',
      subtitle:
          'Search by return number or supplier and refresh the return queue in place.',
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search by Return # or supplier',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => _load(),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_loading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }
}

class _ReturnFormPage extends ConsumerStatefulWidget {
  const _ReturnFormPage();
  @override
  ConsumerState<_ReturnFormPage> createState() => _ReturnFormPageState();
}

class _ReturnFormPageState extends ConsumerState<_ReturnFormPage> {
  int? _supplierId;
  String? _supplierName;
  int? _linkedPurchaseId;
  Map<String, dynamic>? _linkedPurchase;
  bool _loadingLink = false;
  final _reason = TextEditingController();
  final _receiptNumber = TextEditingController();
  String? _receiptFilePath;
  final List<_RetLine> _lines = [
    _RetLine(),
  ];

  List<_RetLine> get _activeLines => _lines
      .where(
        (line) =>
            line.product != null &&
            (double.tryParse(line.qty.text.trim()) ?? 0) > 0,
      )
      .toList(growable: false);

  double get _totalQty => _activeLines.fold<double>(
        0,
        (sum, line) => sum + (double.tryParse(line.qty.text.trim()) ?? 0),
      );

  @override
  void dispose() {
    _reason.dispose();
    _receiptNumber.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _pickSourcePurchase() async {
    final supplierId = _supplierId;
    if (supplierId == null) return;
    setState(() {
      _loadingLink = true;
    });
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      final listRec =
          await repo.getOrders(status: 'RECEIVED', supplierId: supplierId);
      final listPar = await repo.getOrders(
          status: 'PARTIALLY_RECEIVED', supplierId: supplierId);
      final list = [...listRec, ...listPar];
      if (list.isEmpty) {
        if (!mounted) return;
        setState(() {
          _linkedPurchaseId = null;
          _linkedPurchase = null;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('No received or partially received purchase found'),
          ));
        return;
      }

      int? selected = _linkedPurchaseId;
      if (!mounted) return;
      final choice = await showDialog<int?>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setInner) => AlertDialog(
            title: const Text('Select Source Purchase'),
            content: SizedBox(
              width: 720,
              child: SizedBox(
                height: 360,
                child: RadioGroup<int>(
                  groupValue: selected,
                  onChanged: (value) => setInner(() => selected = value),
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return RadioListTile<int>(
                        value: item['purchase_id'] as int,
                        title: Text(item['purchase_number']?.toString() ?? ''),
                        subtitle: Text([
                          if ((item['supplier']?['name'] ??
                                  item['supplier_name'] ??
                                  '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            (item['supplier']?['name'] ?? item['supplier_name'])
                                .toString(),
                          if ((item['status'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            (item['status']).toString(),
                        ].join(' • ')),
                      );
                    },
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Select'),
              ),
            ],
          ),
        ),
      );
      if (choice == null) return;
      final po = await repo.getPurchase(choice);
      if (!mounted) return;
      setState(() {
        _linkedPurchaseId = choice;
        _linkedPurchase = po;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLink = false;
        });
      }
    }
  }

  Future<void> _pickReceiptFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (res != null && res.files.single.path != null) {
      setState(() => _receiptFilePath = res.files.single.path);
    }
  }

  Future<void> _save() async {
    final supplierId = _supplierId;
    if (supplierId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Select supplier')));
      return;
    }
    try {
      final payload = <Map<String, dynamic>>[];
      for (final l in _lines) {
        if (l.product == null) continue;
        final qty = double.tryParse(l.qty.text.trim()) ?? 0;
        if (qty <= 0) continue;
        final price = double.tryParse(l.price.text.trim()) ?? 0;
        final tracking = l.tracking;
        if (tracking == null) {
          throw StateError(
            'Configure variation / tracking for ${l.product!.name}',
          );
        }
        payload.add({
          'product_id': l.product!.productId,
          'quantity': qty,
          'unit_price': price,
          ...tracking.toIssueJson(),
        });
      }
      if (payload.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('Enter quantities to return')));
        return;
      }

      if (_linkedPurchaseId == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Select a source purchase first')),
          );
        return;
      }
      final purchaseId = _linkedPurchaseId!;
      final purchase = _linkedPurchase!;
      // map purchase_detail_id if available
      final details =
          (purchase['items'] as List? ?? const []).cast<Map<String, dynamic>>();
      final usedDetailIds = <int>{};
      for (final p in payload) {
        final match = _matchPurchaseDetail(
          details: details,
          payload: p,
          usedDetailIds: usedDetailIds,
        );
        final pdid = match['purchase_detail_id'] as int?;
        if (pdid != null) {
          p['purchase_detail_id'] = pdid;
          usedDetailIds.add(pdid);
        }
      }

      int id;
      try {
        id = await ref.read(purchaseReturnsRepositoryProvider).createReturn(
              purchaseId: purchaseId,
              items: payload,
              reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
            );
      } on NegativeStockApprovalRequiredException catch (e) {
        if (!mounted) return;
        final password = await showNegativeStockApprovalDialog(
          context,
          message: e.message,
        );
        if (password == null || password.isEmpty) return;
        id = await ref.read(purchaseReturnsRepositoryProvider).createReturn(
              purchaseId: purchaseId,
              items: payload,
              reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
              overridePassword: password,
            );
      }
      final file = (_receiptFilePath ?? '').trim();
      final number = _receiptNumber.text.trim();
      if (file.isNotEmpty) {
        try {
          await ref.read(purchaseReturnsRepositoryProvider).uploadReceipt(
              returnId: id,
              filePath: file,
              receiptNumber: number.isEmpty ? null : number);
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('New Purchase Return'),
      ),
      body: SafeArea(
        child: isDesktop ? _buildDesktopBody() : _buildMobileBody(),
      ),
    );
  }

  Widget _buildDesktopBody() {
    const gap = 12.0;
    const railWidth = 320.0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          ProfessionalDocumentHeader(
            title: 'Purchase Return Workspace',
            subtitle:
                'Desktop returns now require an explicit source purchase so the operator can verify the commercial origin before posting stock outflow.',
            badges: [
              const ProfessionalBadge(label: 'Purchase Return'),
              if (_linkedPurchaseId != null)
                const ProfessionalBadge(
                  label: 'Source Selected',
                  backgroundColor: Color(0xFFEAF1F8),
                  foregroundColor: Color(0xFF23415F),
                ),
            ],
          ),
          if (_loadingLink) ...[
            const SizedBox(height: gap),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: gap),
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildReturnOverviewCard()),
                const SizedBox(width: gap),
                Expanded(child: _buildSourcePurchaseCard()),
                const SizedBox(width: gap),
                SizedBox(width: railWidth, child: _buildReturnSummaryCard()),
              ],
            ),
          ),
          const SizedBox(height: gap),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildReturnLinesSection()),
                const SizedBox(width: gap),
                SizedBox(width: railWidth, child: _buildReturnActionPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfessionalDocumentHeader(
          title: 'New Purchase Return',
          subtitle:
              'Mobile keeps the return flow stacked while still making the source purchase an explicit operator choice.',
          badges: [
            ProfessionalBadge(label: '${_activeLines.length} Active Lines'),
          ],
        ),
        if (_loadingLink) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 12),
        _buildReturnOverviewCard(),
        const SizedBox(height: 12),
        _buildSourcePurchaseCard(),
        const SizedBox(height: 12),
        _buildReturnLinesSection(),
        const SizedBox(height: 12),
        _buildReturnSummaryCard(),
        const SizedBox(height: 12),
        _buildReturnActionPanel(),
      ],
    );
  }

  Widget _buildReturnOverviewCard() {
    return ProfessionalOverviewCard(
      title: 'Supplier & Return Notes',
      icon: Icons.assignment_return_rounded,
      child: Column(
        children: [
          PurchaseSupplierPicker(
            supplierId: _supplierId,
            supplierName: _supplierName,
            onPicked: (id, name) async {
              setState(() {
                _supplierId = id;
                _supplierName = name;
                _linkedPurchaseId = null;
                _linkedPurchase = null;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            minLines: 3,
            maxLines: 4,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.description_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePurchaseCard() {
    final purchase = _linkedPurchase;
    final purchaseNumber = purchase?['purchase_number']?.toString() ?? '';
    return ProfessionalSectionCard(
      title: 'Source Purchase',
      subtitle:
          'Select the purchase order that authorizes this return so the stock and commercial trail stay explicit.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.tonalIcon(
            onPressed: _supplierId == null ? null : _pickSourcePurchase,
            icon: const Icon(Icons.search_rounded),
            label: Text(
              purchaseNumber.isEmpty
                  ? 'Select Source Purchase'
                  : 'Change Source',
            ),
            style: professionalCompactButtonStyle(context),
          ),
          const SizedBox(height: 12),
          ProfessionalFieldGrid(
            fields: [
              ProfessionalFieldGridItem(
                label: 'Selected Source',
                value: purchaseNumber.isEmpty ? 'Not selected' : purchaseNumber,
              ),
              ProfessionalFieldGridItem(
                label: 'Supplier Match',
                value: _supplierName ??
                    (_supplierId == null
                        ? 'Select supplier first'
                        : 'Supplier selected'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _receiptNumber,
            decoration: const InputDecoration(
              labelText: 'Return Receipt Number (optional)',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Return Receipt (optional)',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _receiptFilePath == null
                        ? 'No file selected'
                        : (_receiptFilePath!.split('\\').last.split('/').last),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickReceiptFile,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Choose File'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReturnLinesSection() {
    final isDesktop = AppBreakpoints.isDesktop(context);
    return ProfessionalSectionCard(
      title: 'Return Lines',
      subtitle:
          'Add products, quantities, and final issue tracking for every item leaving stock.',
      action: FilledButton.tonalIcon(
        onPressed: () => setState(() => _lines.add(_RetLine())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
        style: professionalCompactButtonStyle(context),
      ),
      expandChild: isDesktop,
      child: _lines.isEmpty
          ? const Center(
              child: ProfessionalDocumentEmptyState(
                title: 'No return lines',
                message: 'Add at least one line before saving the return.',
              ),
            )
          : isDesktop
              ? ListView(
                  padding: EdgeInsets.zero,
                  children: _buildLines(context),
                )
              : Column(children: _buildLines(context)),
    );
  }

  Widget _buildReturnSummaryCard() {
    return ProfessionalSummaryCard(
      title: 'Return Summary',
      expandContent: AppBreakpoints.isDesktop(context),
      rows: [
        (
          label: 'Active Lines',
          value: '${_activeLines.length}',
          emphasize: false,
        ),
        (
          label: 'Total Qty',
          value: _totalQty.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Source Purchase',
          value: _linkedPurchaseId == null ? 'Required' : 'Selected',
          emphasize: true,
        ),
      ],
      footer: Text(
        'Returns now require an explicit source purchase instead of silently choosing the latest one.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _buildReturnActionPanel() {
    return ProfessionalSectionCard(
      title: 'Post Return',
      subtitle:
          'Save the return once supplier, source purchase, and item tracking are fully confirmed.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text('Save Return'),
            style: professionalCompactButtonStyle(context),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLines(BuildContext context) {
    Theme.of(context);
    final details = ((_linkedPurchase?['items'] as List?) ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final Map<int, double> defaultPrices = {
      for (final it in details)
        if (it['product_id'] != null)
          (it['product_id'] as int): ((it['unit_price'] as num?)?.toDouble() ??
              (it['price'] as num?)?.toDouble() ??
              0.0),
    };
    return [
      for (int i = 0; i < _lines.length; i++)
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              PurchaseProductPicker(
                product: _lines[i].product,
                onPicked: (picked) {
                  setState(() {
                    _lines[i].product = picked;
                    _lines[i].tracking = null;
                  });
                  final current = _lines[i].price.text.trim();
                  if (current.isEmpty) {
                    final defaultPrice = defaultPrices[picked.productId];
                    if (defaultPrice != null) {
                      _lines[i].price.text = defaultPrice.toStringAsFixed(2);
                    } else if (picked.price != null) {
                      _lines[i].price.text = picked.price!.toStringAsFixed(2);
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _lines[i].qty,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Quantity',
                            prefixIcon:
                                Icon(Icons.format_list_numbered_rounded)))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _lines[i].price,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Unit Price',
                            prefixIcon: Icon(Icons.currency_rupee_rounded)))),
                IconButton(
                    onPressed: _lines.length == 1
                        ? null
                        : () => setState(() => _lines.removeAt(i)),
                    icon: const Icon(Icons.delete_outline_rounded))
              ]),
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
            ]),
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
      mode: InventoryTrackingMode.issue,
      initialSelection: line.tracking,
    );
    if (selection != null && mounted) {
      setState(() => line.tracking = selection);
    }
  }

  Map<String, dynamic> _matchPurchaseDetail({
    required List<Map<String, dynamic>> details,
    required Map<String, dynamic> payload,
    required Set<int> usedDetailIds,
  }) {
    final productId = payload['product_id'] as int?;
    final barcodeId = payload['barcode_id'] as int?;
    for (final detail in details) {
      final detailId = detail['purchase_detail_id'] as int?;
      if (detailId == null || usedDetailIds.contains(detailId)) continue;
      if (detail['product_id'] != productId) continue;
      if (barcodeId != null && detail['barcode_id'] == barcodeId) {
        return detail;
      }
    }
    for (final detail in details) {
      final detailId = detail['purchase_detail_id'] as int?;
      if (detailId == null || usedDetailIds.contains(detailId)) continue;
      if (detail['product_id'] == productId) {
        return detail;
      }
    }
    return const {};
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
