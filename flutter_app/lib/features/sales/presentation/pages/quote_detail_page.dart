import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sales_repository.dart';
import 'quote_form_page.dart';

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
      setState(() => _error = e.toString());
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
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Share Quote'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(salesRepositoryProvider)
          .shareQuote(widget.quoteId, controller.text.trim());
      await _load();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _quote;
    final items = (q?['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final status = q?['status']?.toString() ?? 'DRAFT';
    final number = q?['quote_number']?.toString() ?? '';
    final customer = q?['customer'] as Map<String, dynamic>?;
    final customerName = (customer?['name']?.toString() ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(number.isEmpty ? 'Quote #${widget.quoteId}' : number),
        actions: [
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
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'sent':
                  await _updateStatus('SENT');
                  break;
                case 'accepted':
                  await _updateStatus('ACCEPTED');
                  break;
                case 'print':
                  await ref.read(salesRepositoryProvider).printQuote(widget.quoteId);
                  await _load();
                  break;
                case 'share':
                  await _share();
                  break;
                case 'delete':
                  await _delete();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'sent', child: Text('Mark Sent')),
              PopupMenuItem(value: 'accepted', child: Text('Mark Accepted')),
              PopupMenuItem(value: 'print', child: Text('Print')),
              PopupMenuItem(value: 'share', child: Text('Share')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (q != null) ...[
              Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.request_quote_rounded),
                  title: Text(number.isEmpty ? 'Quote' : number),
                  subtitle: Text([
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
