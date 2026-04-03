import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/negative_stock_override.dart';
import '../../data/sales_repository.dart';
import '../utils/quote_actions.dart';
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
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => QuoteFormPage(quoteId: widget.quoteId)),
    );
    if (res == true) {
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
    final status = _quote?['status']?.toString() ?? 'DRAFT';
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
            'Convert this accepted quote into a sale? This will create a new sale record.'),
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
      var saleId = await ref.read(salesRepositoryProvider).convertQuoteToSale(
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
      try {
        final saleId =
            await ref.read(salesRepositoryProvider).convertQuoteToSale(
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
      try {
        final saleId =
            await ref.read(salesRepositoryProvider).convertQuoteToSale(
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    } finally {
      if (mounted) setState(() => _converting = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _quote;
    final items =
        (q?['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final status = q?['status']?.toString() ?? 'DRAFT';
    final transactionType = q?['transaction_type']?.toString() ?? 'B2B';
    final convertedSaleId = q?['converted_sale_id'] as int?;
    final isConverted = convertedSaleId != null || status == 'CONVERTED';
    final number = q?['quote_number']?.toString() ?? '';
    final customer = q?['customer'] as Map<String, dynamic>?;
    final customerName = (customer?['name']?.toString() ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(number.isEmpty ? 'Quote #${widget.quoteId}' : number),
        actions: [
          if (!isConverted)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_rounded),
              onPressed: q == null ? null : _edit,
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_rounded),
            onPressed: q == null ? null : _print,
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_rounded),
            onPressed: q == null ? null : _share,
          ),
          if (!isConverted)
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
      bottomNavigationBar: (q == null || isConverted)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: (_converting || status != 'ACCEPTED')
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
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (q != null && isConverted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Card(
                  elevation: 0,
                  color: theme.colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.lock_rounded),
                    title: const Text('Converted to Sale'),
                    subtitle: Text(convertedSaleId == null
                        ? 'This quote is now read-only.'
                        : 'Sale #$convertedSaleId created. This quote is now read-only.'),
                  ),
                ),
              ),
            if (q != null) ...[
              Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.request_quote_rounded),
                  title: Text(number.isEmpty ? 'Quote' : number),
                  subtitle: Text([
                    'Type: $transactionType',
                    if (customerName.isNotEmpty) customerName,
                    'Status: $status',
                  ].join(' - ')),
                  trailing: Text(
                    ((q['total_amount'] as num?)?.toDouble() ?? 0.0)
                        .toStringAsFixed(2),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                child: Column(children: [
                  const ListTile(title: Text('Items')),
                  const Divider(height: 1),
                  if (items.isEmpty)
                    const ListTile(title: Text('No items'))
                  else
                    for (final it in items)
                      ListTile(
                        leading: const Icon(Icons.inventory_2_rounded),
                        title: Text(
                          it['product_name']?.toString() ??
                              it['product']?['name']?.toString() ??
                              'Item',
                        ),
                        subtitle: Text(
                          'Qty: ${(it['quantity'] as num?)?.toDouble() ?? 0} - Price: ${(it['unit_price'] as num?)?.toDouble() ?? 0}',
                        ),
                        trailing: Text(
                          ((it['line_total'] as num?)?.toDouble() ?? 0.0)
                              .toStringAsFixed(2),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
