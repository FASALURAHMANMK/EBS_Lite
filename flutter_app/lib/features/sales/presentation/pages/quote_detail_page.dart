import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../core/negative_stock_override.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/sales_repository.dart';
import '../utils/quote_actions.dart';
import '../widgets/quote_review_widgets.dart';
import 'quote_form_page.dart';
import 'sale_detail_page.dart';

class QuoteDetailPage extends ConsumerStatefulWidget {
  const QuoteDetailPage({super.key, required this.quoteId});
  final int quoteId;

  @override
  ConsumerState<QuoteDetailPage> createState() => _QuoteDetailPageState();
}

class _QuoteDetailPageState extends ConsumerState<QuoteDetailPage> {
  Map<String, dynamic>? _quote;
  bool _loading = true;
  String? _error;
  bool _converting = false;

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
      final quote = await repo.getQuote(widget.quoteId);
      if (!mounted) return;
      setState(() => _quote = quote);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.of(context).push<QuoteWorkflowResult>(
      MaterialPageRoute(
        builder: (_) => QuoteFormPage(
          quoteId: widget.quoteId,
          returnResultOnSave: true,
        ),
      ),
    );
    if (result != null) {
      await _load();
    }
  }

  Future<void> _updateStatus(String status) async {
    final repo = ref.read(salesRepositoryProvider);
    await repo.updateQuote(widget.quoteId, status: status);
    await _load();
  }

  Future<void> _share() async {
    await QuoteActions(ref: ref, context: context).shareQuote(widget.quoteId);
    await _load();
  }

  Future<void> _print() async {
    await QuoteActions(ref: ref, context: context).printQuote(widget.quoteId);
    await _load();
  }

  Future<void> _convertToSale() async {
    if (_converting) return;
    final snapshot = _quote == null ? null : QuoteDocumentSnapshot(_quote!);
    final status = snapshot?.status ?? 'DRAFT';
    if (status != 'ACCEPTED') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mark the quote as ACCEPTED first.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Convert to Sale'),
        content: const Text(
          'Convert this accepted quote into a sale? This will create a new sale record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _converting = true);
    try {
      final saleId = await ref.read(salesRepositoryProvider).convertQuoteToSale(
            widget.quoteId,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: saleId)),
      );
      await _load();
    } on NegativeStockApprovalRequiredException catch (e) {
      if (!mounted) return;
      final password = await showNegativeStockApprovalDialog(
        context,
        message: e.message,
      );
      if (!mounted) return;
      if (password == null || password.isEmpty) {
        setState(() => _converting = false);
        return;
      }
      await _convertWithOverride(password);
    } on NegativeProfitApprovalRequiredException catch (e) {
      if (!mounted) return;
      final password = await showNegativeProfitApprovalDialog(
        context,
        message: e.message,
      );
      if (!mounted) return;
      if (password == null || password.isEmpty) {
        setState(() => _converting = false);
        return;
      }
      await _convertWithOverride(password);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  Future<void> _convertWithOverride(String password) async {
    try {
      final saleId = await ref.read(salesRepositoryProvider).convertQuoteToSale(
            widget.quoteId,
            overridePassword: password,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: saleId)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Quote'),
        content: const Text('Are you sure you want to delete this quote?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(salesRepositoryProvider).deleteQuote(widget.quoteId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleMenuAction(String value) async {
    switch (value) {
      case 'sent':
        await _updateStatus('SENT');
        break;
      case 'accepted':
        await _updateStatus('ACCEPTED');
        break;
      case 'convert':
        await _convertToSale();
        break;
      case 'delete':
        await _delete();
        break;
    }
  }

  Widget _buildSummaryActions(QuoteDocumentSnapshot quote, bool isDesktop) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!quote.isConverted)
          FilledButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit'),
            style: professionalCompactButtonStyle(context),
          ),
        FilledButton.tonalIcon(
          onPressed: _print,
          icon: const Icon(Icons.print_rounded),
          label: const Text('Print'),
          style: professionalCompactButtonStyle(context),
        ),
        FilledButton.tonalIcon(
          onPressed: _share,
          icon: const Icon(Icons.share_rounded),
          label: const Text('Share'),
          style: professionalCompactButtonStyle(context),
        ),
        if (!quote.isConverted)
          FilledButton.icon(
            onPressed: (_converting || quote.status != 'ACCEPTED')
                ? null
                : _convertToSale,
            icon: _converting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.receipt_long_rounded),
            label: Text(
              _converting
                  ? 'Converting…'
                  : (isDesktop ? 'Convert to Sale' : 'Convert'),
            ),
            style: professionalCompactButtonStyle(context),
          ),
      ],
    );
  }

  Widget _buildBody(
    QuoteDocumentSnapshot quote,
    LocalePreferencesState localePrefs,
  ) {
    final isDesktop = AppBreakpoints.isDesktop(context);

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            QuoteDocumentHeaderCard(quote: quote),
            const SizedBox(height: 12),
            QuoteConvertedBanner(quote: quote),
            if (quote.isConverted) const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: QuoteOverviewSection(
                      quote: quote,
                      localePrefs: localePrefs,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 340,
                    child: QuoteSummarySection(
                      quote: quote,
                      isDesktop: true,
                      footer: _buildSummaryActions(quote, true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  QuoteItemsSection(quote: quote),
                  if (quote.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    QuoteNotesSection(quote: quote),
                  ],
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
        QuoteDocumentHeaderCard(quote: quote),
        const SizedBox(height: 12),
        QuoteConvertedBanner(quote: quote),
        if (quote.isConverted) const SizedBox(height: 12),
        QuoteOverviewSection(
          quote: quote,
          localePrefs: localePrefs,
        ),
        const SizedBox(height: 12),
        QuoteItemsSection(quote: quote),
        const SizedBox(height: 12),
        QuoteSummarySection(
          quote: quote,
          isDesktop: false,
          footer: _buildSummaryActions(quote, false),
        ),
        if (quote.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          QuoteNotesSection(quote: quote),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);
    final quote = _quote == null ? null : QuoteDocumentSnapshot(_quote!);
    final showSidebarToggle = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showSidebarToggle ? 104 : null,
        leading: showSidebarToggle ? const DesktopSidebarToggleLeading() : null,
        title: Text(quote?.title ?? 'Quote #${widget.quoteId}'),
        actions: [
          if (quote != null && !quote.isConverted)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_rounded),
              onPressed: _edit,
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_rounded),
            onPressed: quote == null ? null : _print,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_rounded),
            onPressed: quote == null ? null : _share,
          ),
          if (quote != null && !quote.isConverted)
            PopupMenuButton<String>(
              onSelected: (value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  // ignore: unawaited_futures
                  _handleMenuAction(value);
                });
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'sent', child: Text('Mark Sent')),
                PopupMenuItem(value: 'accepted', child: Text('Mark Accepted')),
                PopupMenuItem(value: 'convert', child: Text('Convert to Sale')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: (!isDesktop && quote != null && !quote.isConverted)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: (_converting || quote.status != 'ACCEPTED')
                      ? null
                      : _convertToSale,
                  icon: _converting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long_rounded),
                  label: Text(_converting ? 'Converting…' : 'Convert to Sale'),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: _loading && quote == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && quote == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ProfessionalDocumentEmptyState(
                        title: 'Unable to load quote details',
                        message: _error!,
                        actionLabel: 'Retry',
                        onAction: _load,
                        icon: Icons.error_outline_rounded,
                      ),
                    ),
                  )
                : quote == null
                    ? const Center(child: Text('Quote not found'))
                    : _buildBody(quote, localePrefs),
      ),
    );
  }
}
