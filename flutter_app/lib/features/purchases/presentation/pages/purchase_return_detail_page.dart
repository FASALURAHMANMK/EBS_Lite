import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/purchase_returns_repository.dart';

class PurchaseReturnDetailPage extends ConsumerStatefulWidget {
  const PurchaseReturnDetailPage({super.key, required this.returnId});

  final int returnId;

  @override
  ConsumerState<PurchaseReturnDetailPage> createState() =>
      _PurchaseReturnDetailPageState();
}

class _PurchaseReturnDetailPageState
    extends ConsumerState<PurchaseReturnDetailPage> {
  Map<String, dynamic>? _doc;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doc = await ref
          .read(purchaseReturnsRepositoryProvider)
          .getReturn(widget.returnId);
      if (!mounted) return;
      setState(() => _doc = doc);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final doc = _doc;
    final items =
        (doc?['items'] as List? ?? const []).cast<Map<String, dynamic>>();
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

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: Text(doc?['return_number']?.toString() ?? 'Purchase Return'),
      ),
      body: SafeArea(
        child: _loading && doc == null
            ? const Center(child: CircularProgressIndicator())
            : doc == null
                ? const Center(child: Text('Purchase return not found'))
                : (isDesktop
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            _buildHeader(doc),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 170,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                      child: _buildOverview(doc, localePrefs)),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 320,
                                    child: _buildSummary(totalQty, totalValue),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(child: _buildItemsSection(items)),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildHeader(doc),
                          const SizedBox(height: 12),
                          _buildOverview(doc, localePrefs),
                          const SizedBox(height: 12),
                          _buildItemsSection(items),
                          const SizedBox(height: 12),
                          _buildSummary(totalQty, totalValue),
                        ],
                      )),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> doc) {
    return ProfessionalDocumentHeader(
      title: doc['return_number']?.toString() ?? 'Purchase Return',
      subtitle:
          'Return review keeps supplier context, source purchase, and posted quantities visible for stock and finance reconciliation.',
      badges: [
        const ProfessionalBadge(
          label: 'Purchase Return',
          backgroundColor: Color(0xFFFFF1D6),
          foregroundColor: Color(0xFF8A5200),
        ),
        if ((doc['supplier']?['name'] ?? '').toString().trim().isNotEmpty)
          ProfessionalBadge(label: doc['supplier']['name'].toString()),
        if ((doc['purchase']?['purchase_number'] ?? '')
            .toString()
            .trim()
            .isNotEmpty)
          const ProfessionalBadge(
            label: 'Source Linked',
            backgroundColor: Color(0xFFEAF1F8),
            foregroundColor: Color(0xFF23415F),
          ),
      ],
    );
  }

  Widget _buildOverview(
    Map<String, dynamic> doc,
    LocalePreferencesState localePrefs,
  ) {
    return ProfessionalOverviewCard(
      title: 'Return Overview',
      icon: Icons.assignment_return_rounded,
      child: ProfessionalFieldGrid(
        fields: [
          ProfessionalFieldGridItem(
            label: 'Supplier',
            value: (doc['supplier']?['name'] ?? '').toString().trim().isEmpty
                ? 'Not available'
                : doc['supplier']['name'].toString(),
          ),
          ProfessionalFieldGridItem(
            label: 'Return Date',
            value: AppDateTime.formatFlexibleDate(
              context,
              localePrefs,
              doc['return_date']?.toString(),
              fallback: doc['return_date']?.toString() ?? 'Not available',
            ),
          ),
          ProfessionalFieldGridItem(
            label: 'Source Purchase',
            value: (doc['purchase']?['purchase_number'] ?? '')
                    .toString()
                    .trim()
                    .isEmpty
                ? 'Not set'
                : doc['purchase']['purchase_number'].toString(),
          ),
          ProfessionalFieldGridItem(
            label: 'Reason',
            value: (doc['reason'] ?? '').toString().trim().isEmpty
                ? 'No reason recorded'
                : doc['reason'].toString(),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(List<Map<String, dynamic>> items) {
    return ProfessionalSectionCard(
      title: 'Returned Items',
      subtitle:
          'Review posted quantities and return pricing for each line in the document.',
      child: items.isEmpty
          ? const ProfessionalDocumentEmptyState(
              title: 'No returned items',
              message: 'This return does not contain line items.',
            )
          : Column(
              children: [
                for (final item in items) ...[
                  ProfessionalOverviewCard(
                    title: item['product']?['name']?.toString() ??
                        'Product #${item['product_id']}',
                    icon: Icons.inventory_2_rounded,
                    child: ProfessionalFieldGrid(
                      fields: [
                        ProfessionalFieldGridItem(
                          label: 'Quantity',
                          value: ((item['quantity'] as num?)?.toDouble() ?? 0)
                              .toStringAsFixed(2),
                        ),
                        ProfessionalFieldGridItem(
                          label: 'Unit Price',
                          value: ((item['unit_price'] as num?)?.toDouble() ?? 0)
                              .toStringAsFixed(2),
                        ),
                      ],
                    ),
                  ),
                  if (item != items.last) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  Widget _buildSummary(double totalQty, double totalValue) {
    return ProfessionalSummaryCard(
      title: 'Return Summary',
      expandContent: AppBreakpoints.isDesktop(context),
      rows: [
        (
          label: 'Item Count',
          value: '${(_doc?['items'] as List? ?? const []).length}',
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
    );
  }
}
