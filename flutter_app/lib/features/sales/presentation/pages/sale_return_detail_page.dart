import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/sales_repository.dart';
import '../widgets/sale_return_review_widgets.dart';
import 'sale_detail_page.dart';

class SaleReturnDetailPage extends ConsumerStatefulWidget {
  const SaleReturnDetailPage({super.key, required this.returnId});

  final int returnId;

  @override
  ConsumerState<SaleReturnDetailPage> createState() =>
      _SaleReturnDetailPageState();
}

class _SaleReturnDetailPageState extends ConsumerState<SaleReturnDetailPage> {
  Map<String, dynamic>? _doc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(salesRepositoryProvider);
      final doc = await repo.getSaleReturn(widget.returnId);
      if (!mounted) return;
      setState(() => _doc = doc);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ErrorHandler.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSourceSale() async {
    final saleId = (_doc?['sale_id'] as num?)?.toInt();
    if (saleId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: saleId)),
    );
  }

  Widget _buildActionFooter(
    SaleReturnDocumentSnapshot document, {
    required bool isDesktop,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: document.saleId == null ? null : _openSourceSale,
          icon: const Icon(Icons.receipt_long_rounded),
          label: Text(isDesktop ? 'View Source Invoice' : 'Source Invoice'),
          style: professionalCompactButtonStyle(context),
        ),
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
          style: professionalCompactButtonStyle(
            context,
            outlined: true,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    SaleReturnDocumentSnapshot document,
    LocalePreferencesState localePrefs,
  ) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) ...[
              ProfessionalBanner(
                message: _error!,
                color: Theme.of(context).colorScheme.errorContainer,
              ),
              const SizedBox(height: 12),
            ],
            SaleReturnDocumentHeaderCard(document: document),
            const SizedBox(height: 12),
            SizedBox(
              height: 205,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SaleReturnOverviewSection(
                      document: document,
                      localePrefs: localePrefs,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 340,
                    child: SaleReturnSummarySection(
                      document: document,
                      isDesktop: true,
                      footer: _buildActionFooter(document, isDesktop: true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  SaleReturnItemsSection(document: document),
                  const SizedBox(height: 12),
                  SaleReturnReasonSection(document: document),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null) ...[
          ProfessionalBanner(
            message: _error!,
            color: Theme.of(context).colorScheme.errorContainer,
          ),
          const SizedBox(height: 12),
        ],
        SaleReturnDocumentHeaderCard(document: document),
        const SizedBox(height: 12),
        SaleReturnOverviewSection(
          document: document,
          localePrefs: localePrefs,
        ),
        const SizedBox(height: 12),
        SaleReturnItemsSection(document: document),
        const SizedBox(height: 12),
        SaleReturnSummarySection(
          document: document,
          isDesktop: false,
          footer: _buildActionFooter(document, isDesktop: false),
        ),
        const SizedBox(height: 12),
        SaleReturnReasonSection(document: document),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);
    final doc = _doc;
    final document = doc == null ? null : SaleReturnDocumentSnapshot(doc);
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final saleId = document?.saleId;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: Text(document?.title ?? 'Sale Return'),
        actions: [
          IconButton(
            tooltip: 'View source invoice',
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: saleId == null ? null : _openSourceSale,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _loading && document == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && document == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ProfessionalDocumentEmptyState(
                        title: 'Unable to load sale return',
                        message: _error!,
                        actionLabel: 'Retry',
                        onAction: _load,
                        icon: Icons.error_outline_rounded,
                      ),
                    ),
                  )
                : document == null
                    ? const Center(child: Text('Sale return not found'))
                    : _buildBody(document, localePrefs),
      ),
    );
  }
}
