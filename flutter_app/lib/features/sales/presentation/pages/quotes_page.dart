import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../core/negative_stock_override.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/desktop_sidebar_toggle_action.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/sales_repository.dart';
import '../utils/quote_actions.dart';
import '../widgets/quote_review_widgets.dart';
import '../widgets/sales_workbench_widgets.dart';
import 'quote_detail_page.dart';
import 'quote_form_page.dart';
import 'sale_detail_page.dart';

class QuotesPage extends ConsumerStatefulWidget {
  const QuotesPage({super.key});

  @override
  ConsumerState<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends ConsumerState<QuotesPage> {
  final _search = TextEditingController();

  bool _loading = true;
  bool _detailLoading = false;
  bool _actionBusy = false;
  Object? _error;
  Object? _detailError;
  List<Map<String, dynamic>> _quotes = const [];
  String _statusFilter = 'ALL';
  String _transactionTypeFilter = 'ALL';
  int? _selectedQuoteId;
  int? _selectionTargetQuoteId;
  Map<String, dynamic>? _selectedQuote;
  int _detailRequestToken = 0;

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

  List<QuoteDocumentSnapshot> _buildVisibleDocuments(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    final documents =
        _quotes.map(QuoteDocumentSnapshot.new).toList(growable: false)
          ..sort((a, b) {
            final aDate = a.quoteDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.quoteDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
    if (normalizedQuery.isEmpty) {
      return documents;
    }
    return documents.where((document) {
      return document.title.toLowerCase().contains(normalizedQuery) ||
          document.customerLabel.toLowerCase().contains(normalizedQuery) ||
          document.status.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  Future<void> _load({int? selectQuoteId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(salesRepositoryProvider);
      final list = await repo.getQuotes(
        status: _statusFilter == 'ALL' ? null : _statusFilter,
        transactionType:
            _transactionTypeFilter == 'ALL' ? null : _transactionTypeFilter,
      );
      if (!mounted) return;
      setState(() {
        _quotes = list;
        _selectionTargetQuoteId = selectQuoteId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncDesktopSelection(List<QuoteDocumentSnapshot> documents) {
    if (!mounted) return;
    if (documents.isEmpty) {
      if (_selectedQuoteId != null ||
          _selectedQuote != null ||
          _detailError != null ||
          _detailLoading) {
        setState(() {
          _selectedQuoteId = null;
          _selectedQuote = null;
          _detailError = null;
          _detailLoading = false;
        });
      }
      return;
    }

    QuoteDocumentSnapshot? next;
    final targetQuoteId = _selectionTargetQuoteId;
    if (targetQuoteId != null) {
      for (final document in documents) {
        if (document.quoteId == targetQuoteId) {
          next = document;
          break;
        }
      }
    }

    if (next == null && _selectedQuoteId != null) {
      for (final document in documents) {
        if (document.quoteId == _selectedQuoteId) {
          next = document;
          break;
        }
      }
    }
    next ??= documents.first;

    if (_selectionTargetQuoteId != null) {
      _selectionTargetQuoteId = null;
    }

    if (_selectedQuoteId != next.quoteId ||
        (_selectedQuote == null && !_detailLoading && _detailError == null)) {
      _selectQuote(next);
    }
  }

  Future<void> _selectQuote(QuoteDocumentSnapshot document) async {
    final quoteId = document.quoteId;
    if (quoteId == null) return;
    if (_selectedQuoteId == quoteId &&
        (_detailLoading || (_selectedQuote?['quote_id'] as int?) == quoteId)) {
      return;
    }

    final requestToken = ++_detailRequestToken;
    setState(() {
      _selectedQuoteId = quoteId;
      _selectedQuote = null;
      _detailError = null;
      _detailLoading = true;
    });

    try {
      final quote = await ref.read(salesRepositoryProvider).getQuote(quoteId);
      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() {
        _selectedQuote = quote;
        _detailLoading = false;
      });
    } catch (error) {
      if (!mounted || requestToken != _detailRequestToken) return;
      setState(() {
        _detailError = error;
        _detailLoading = false;
      });
    }
  }

  Future<void> _reloadSelection({int? selectQuoteId}) async {
    await _load(selectQuoteId: selectQuoteId ?? _selectedQuoteId);
  }

  Future<void> _openForm({int? quoteId}) async {
    final isDesktop = AppBreakpoints.isDesktop(context);
    final result = await Navigator.of(context).push<QuoteWorkflowResult>(
      MaterialPageRoute(
        builder: (_) => QuoteFormPage(
          quoteId: quoteId,
          returnResultOnSave: true,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) {
      await _reloadSelection(selectQuoteId: quoteId ?? _selectedQuoteId);
      return;
    }
    await _reloadSelection(selectQuoteId: result.quoteId);
    if (!mounted || isDesktop) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuoteDetailPage(quoteId: result.quoteId),
      ),
    );
    await _reloadSelection(selectQuoteId: result.quoteId);
  }

  Future<void> _openSelectedReview() async {
    final quoteId = _selectedQuoteId;
    if (quoteId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => QuoteDetailPage(quoteId: quoteId)),
    );
    await _reloadSelection(selectQuoteId: quoteId);
  }

  Future<void> _printSelectedQuote() async {
    final quoteId = _selectedQuoteId;
    if (quoteId == null) return;
    setState(() => _actionBusy = true);
    try {
      await QuoteActions(ref: ref, context: context).printQuote(quoteId);
      await _reloadSelection(selectQuoteId: quoteId);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _shareSelectedQuote() async {
    final quoteId = _selectedQuoteId;
    if (quoteId == null) return;
    setState(() => _actionBusy = true);
    try {
      await QuoteActions(ref: ref, context: context).shareQuote(quoteId);
      await _reloadSelection(selectQuoteId: quoteId);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _updateSelectedQuoteStatus(String status) async {
    final quoteId = _selectedQuoteId;
    if (quoteId == null) return;
    setState(() => _actionBusy = true);
    try {
      await ref
          .read(salesRepositoryProvider)
          .updateQuote(quoteId, status: status);
      await _reloadSelection(selectQuoteId: quoteId);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _convertSelectedQuote() async {
    final quote =
        _selectedQuote == null ? null : QuoteDocumentSnapshot(_selectedQuote!);
    final quoteId = quote?.quoteId;
    if (quote == null || quoteId == null || _actionBusy) return;
    if (quote.status != 'ACCEPTED') {
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

    setState(() => _actionBusy = true);
    try {
      final saleId =
          await ref.read(salesRepositoryProvider).convertQuoteToSale(quoteId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: saleId)),
      );
      await _reloadSelection(selectQuoteId: quoteId);
    } on NegativeStockApprovalRequiredException catch (e) {
      if (!mounted) return;
      final password = await showNegativeStockApprovalDialog(
        context,
        message: e.message,
      );
      if (!mounted) return;
      if (password == null || password.isEmpty) {
        setState(() => _actionBusy = false);
        return;
      }
      await _convertSelectedQuoteWithOverride(quoteId, password);
    } on NegativeProfitApprovalRequiredException catch (e) {
      if (!mounted) return;
      final password = await showNegativeProfitApprovalDialog(
        context,
        message: e.message,
      );
      if (!mounted) return;
      if (password == null || password.isEmpty) {
        setState(() => _actionBusy = false);
        return;
      }
      await _convertSelectedQuoteWithOverride(quoteId, password);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(error))),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _convertSelectedQuoteWithOverride(
    int quoteId,
    String password,
  ) async {
    try {
      final saleId = await ref.read(salesRepositoryProvider).convertQuoteToSale(
            quoteId,
            overridePassword: password,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: saleId)),
      );
      await _reloadSelection(selectQuoteId: quoteId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(error))),
      );
    }
  }

  Future<void> _deleteSelectedQuote() async {
    final quoteId = _selectedQuoteId;
    if (quoteId == null) return;
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
    if (ok != true) return;

    setState(() => _actionBusy = true);
    try {
      await ref.read(salesRepositoryProvider).deleteQuote(quoteId);
      if (!mounted) return;
      setState(() {
        _selectedQuoteId = null;
        _selectedQuote = null;
      });
      await _load();
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Widget _buildFilters(bool isDesktop) {
    final hasFilter = _statusFilter != 'ALL' || _transactionTypeFilter != 'ALL';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search quote #, customer, or status',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Quote Type'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const ['ALL', 'B2B', 'RETAIL'])
                ChoiceChip(
                  label: Text(
                    option == 'ALL'
                        ? 'All'
                        : option == 'B2B'
                            ? 'B2B'
                            : 'Retail',
                  ),
                  selected: _transactionTypeFilter == option,
                  onSelected: (selected) async {
                    if (!selected || option == _transactionTypeFilter) {
                      return;
                    }
                    setState(() => _transactionTypeFilter = option);
                    await _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isDesktop ? 220 : double.infinity,
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All')),
                    DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                    DropdownMenuItem(value: 'SENT', child: Text('Sent')),
                    DropdownMenuItem(
                      value: 'ACCEPTED',
                      child: Text('Accepted'),
                    ),
                    DropdownMenuItem(
                      value: 'CONVERTED',
                      child: Text('Converted'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null || value == _statusFilter) {
                      return;
                    }
                    setState(() => _statusFilter = value);
                    await _load();
                  },
                ),
              ),
              if (hasFilter)
                TextButton.icon(
                  onPressed: () async {
                    setState(() {
                      _statusFilter = 'ALL';
                      _transactionTypeFilter = 'ALL';
                    });
                    await _load();
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Clear filters'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    ThemeData theme,
    LocalePreferencesState localePrefs,
    List<QuoteDocumentSnapshot> documents,
  ) {
    final selectedQuote =
        _selectedQuote == null ? null : QuoteDocumentSnapshot(_selectedQuote!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: SalesWorkbenchPane(
              title: 'Quotes',
              subtitle: '${documents.length} matching quote(s)',
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: documents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final document = documents[index];
                  return QuoteWorkbenchListTile(
                    quote: document,
                    localePrefs: localePrefs,
                    selected: document.quoteId == _selectedQuoteId,
                    onTap: () => _selectQuote(document),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: SalesWorkbenchPane(
              title: 'Review',
              subtitle: selectedQuote == null
                  ? 'Select a quote from the list'
                  : 'Quote overview and actions',
              headerTrailing: selectedQuote == null
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!selectedQuote.isConverted)
                          IconButton(
                            tooltip: 'Edit selected quote',
                            onPressed: _actionBusy
                                ? null
                                : () =>
                                    _openForm(quoteId: selectedQuote.quoteId),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        if (!selectedQuote.isConverted)
                          PopupMenuButton<String>(
                            tooltip: 'Quote actions',
                            enabled: !_actionBusy,
                            onSelected: (value) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                switch (value) {
                                  case 'sent':
                                    _updateSelectedQuoteStatus('SENT');
                                    break;
                                  case 'accepted':
                                    _updateSelectedQuoteStatus('ACCEPTED');
                                    break;
                                  case 'convert':
                                    _convertSelectedQuote();
                                    break;
                                  case 'delete':
                                    _deleteSelectedQuote();
                                    break;
                                }
                              });
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'sent',
                                child: Text('Mark Sent'),
                              ),
                              PopupMenuItem(
                                value: 'accepted',
                                child: Text('Mark Accepted'),
                              ),
                              PopupMenuItem(
                                value: 'convert',
                                child: Text('Convert to Sale'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                      ],
                    ),
              child: _buildOverviewPane(localePrefs),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: SalesWorkbenchPane(
              title: 'Item Lines',
              subtitle: selectedQuote == null
                  ? 'Item lines appear after a selection'
                  : '${selectedQuote.items.length} line(s)',
              child: _buildItemsPane(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPane(LocalePreferencesState localePrefs) {
    if (_detailLoading && _selectedQuote == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_detailError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ProfessionalDocumentEmptyState(
            title: 'Unable to load quote details',
            message: _detailError.toString(),
            actionLabel: 'Retry',
            onAction: () {
              final documents = _buildVisibleDocuments(_search.text);
              QuoteDocumentSnapshot? selected;
              for (final document in documents) {
                if (document.quoteId == _selectedQuoteId) {
                  selected = document;
                  break;
                }
              }
              if (selected != null) {
                _selectQuote(selected);
              }
            },
            icon: Icons.error_outline_rounded,
          ),
        ),
      );
    }
    final quote =
        _selectedQuote == null ? null : QuoteDocumentSnapshot(_selectedQuote!);
    if (quote == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: ProfessionalDocumentEmptyState(
            title: 'No quote selected',
            message: 'Choose a quote to review its commercial summary.',
            icon: Icons.touch_app_rounded,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
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
        QuoteSummarySection(
          quote: quote,
          isDesktop: false,
          footer: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!quote.isConverted)
                FilledButton.icon(
                  onPressed: _actionBusy
                      ? null
                      : () => _openForm(quoteId: quote.quoteId),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                  style: professionalCompactButtonStyle(context),
                ),
              FilledButton.tonalIcon(
                onPressed: _actionBusy ? null : _printSelectedQuote,
                icon: const Icon(Icons.print_rounded),
                label: const Text('Print'),
                style: professionalCompactButtonStyle(context),
              ),
              FilledButton.tonalIcon(
                onPressed: _actionBusy ? null : _shareSelectedQuote,
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
                style: professionalCompactButtonStyle(context),
              ),
              FilledButton.tonalIcon(
                onPressed: _actionBusy ? null : _openSelectedReview,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open Detail'),
                style: professionalCompactButtonStyle(context),
              ),
              if (!quote.isConverted)
                FilledButton.icon(
                  onPressed: (_actionBusy || quote.status != 'ACCEPTED')
                      ? null
                      : _convertSelectedQuote,
                  icon: _actionBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long_rounded),
                  label: Text(
                    _actionBusy ? 'Working…' : 'Convert to Sale',
                  ),
                  style: professionalCompactButtonStyle(context),
                ),
            ],
          ),
        ),
        if (quote.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          QuoteNotesSection(quote: quote),
        ],
      ],
    );
  }

  Widget _buildItemsPane() {
    if (_detailLoading && _selectedQuote == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_detailError != null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: ProfessionalDocumentEmptyState(
            title: 'Item lines unavailable',
            message: 'Retry quote selection to load line details.',
            icon: Icons.error_outline_rounded,
          ),
        ),
      );
    }
    final quote =
        _selectedQuote == null ? null : QuoteDocumentSnapshot(_selectedQuote!);
    if (quote == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: ProfessionalDocumentEmptyState(
            title: 'No quote selected',
            message: 'Choose a quote to review its item lines.',
            icon: Icons.inventory_2_outlined,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        QuoteItemsSection(quote: quote),
      ],
    );
  }

  Widget _buildMobileList(
    LocalePreferencesState localePrefs,
    List<QuoteDocumentSnapshot> documents,
  ) {
    if (_error != null) {
      return AppErrorView(error: _error!, onRetry: _load);
    }
    if (documents.isEmpty) {
      return const AppEmptyView(
        title: 'No quotes',
        message: 'Quotes will appear here once they are created.',
        icon: Icons.request_quote_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final document = documents[index];
        return QuoteWorkbenchListTile(
          quote: document,
          localePrefs: localePrefs,
          selected: false,
          onTap: () async {
            final quoteId = document.quoteId;
            if (quoteId == null) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuoteDetailPage(quoteId: quoteId),
              ),
            );
            await _reloadSelection(selectQuoteId: quoteId);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localePrefs = ref.watch(localePreferencesProvider);
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final isDesktop = AppBreakpoints.isDesktop(context);
    final documents = _buildVisibleDocuments(_search.text);

    if (isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncDesktopSelection(documents);
      });
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Quotes'),
        actions: [
          IconButton(
            tooltip: 'New Quote',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _openForm(),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(selectQuoteId: _selectedQuoteId),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            _buildFilters(isDesktop),
            Expanded(
              child: isDesktop
                  ? (_error != null
                      ? AppErrorView(error: _error!, onRetry: _load)
                      : documents.isEmpty
                          ? const AppEmptyView(
                              title: 'No quotes',
                              message:
                                  'Quotes will appear here once they are created.',
                              icon: Icons.request_quote_outlined,
                            )
                          : _buildDesktopLayout(theme, localePrefs, documents))
                  : _buildMobileList(localePrefs, documents),
            ),
          ],
        ),
      ),
    );
  }
}
