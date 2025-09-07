import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/controllers/location_notifier.dart';
import '../../controllers/pos_notifier.dart';
import '../../data/models.dart';
import '../../data/pos_repository.dart';
import '../widgets/customer_selector_dialog.dart';
import '../widgets/payment_dialog.dart';

class PosPage extends ConsumerWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posNotifierProvider);
    final notifier = ref.read(posNotifierProvider.notifier);
    final loc = ref.watch(locationNotifierProvider).selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Held Sales',
            icon: const Icon(Icons.inbox_rounded),
            onPressed: () async {
              await showDialog(
                  context: context, builder: (_) => const _HeldSalesDialog());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Row: Receipt number + Customer selection button
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(builder: (context) {
                        final display = state.activeSaleId != null
                            ? (state.committedReceipt ?? '-')
                            : (state.receiptPreview ?? '-');
                        return Text(
                          'Receipt # $display',
                          style: Theme.of(context).textTheme.titleMedium,
                        );
                      }),
                      if (loc != null)
                        Text('Location: ${loc.name}',
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final picked = await showDialog<PosCustomerDto>(
                      context: context,
                      builder: (_) => const CustomerSelectorDialog(),
                    );
                    if (picked != null) notifier.setCustomer(picked);
                  },
                  icon: const Icon(Icons.person_search_rounded),
                  label: const Text('Customer'),
                )
              ],
            ),
          ),
          // Customer name row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Customer: ${state.customerLabel}'),
            ),
          ),
          const SizedBox(height: 8),
          // Product search with live suggestions (show 2)
          _SearchBar(),
          const SizedBox(height: 8),
          // Cart list (scrollable). No extra spacer; bottom bar has own height.
          const Expanded(child: _CartList()),
        ],
      ),
      // Persistent amount + process button
      bottomNavigationBar: _BottomBar(),
    );
  }
}

class _SearchBar extends ConsumerWidget {
  final _controller = TextEditingController();
  _SearchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posNotifierProvider);
    final notifier = ref.read(posNotifierProvider.notifier);
    _controller.value = TextEditingValue(
      text: state.query,
      selection: TextSelection.collapsed(offset: state.query.length),
    );
    final suggestions = state.suggestions.take(2).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search...',
                suffixIcon: IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _controller.clear();
                    ref.read(posNotifierProvider.notifier).setQuery('');
                  },
                )),
            onChanged: notifier.setQuery,
            onSubmitted: (value) {
              // Add first suggestion on enter
              if (suggestions.isNotEmpty) {
                notifier.addProduct(suggestions.first);
              }
            },
          ),
          if (suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: suggestions
                    .map((p) => ListTile(
                          dense: true,
                          title: Text(p.name),
                          subtitle: Text(
                              'Price: ${p.price.toStringAsFixed(2)}  •  Stock: ${p.stock.toStringAsFixed(2)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_rounded),
                            onPressed: () => notifier.addProduct(p),
                          ),
                          onTap: () => notifier.addProduct(p),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartList extends ConsumerWidget {
  const _CartList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posNotifierProvider);
    final notifier = ref.read(posNotifierProvider.notifier);
    if (state.cart.isEmpty) {
      return Center(
        child: Text(
          'No items yet. Search and add products.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemBuilder: (context, index) {
        final item = state.cart[index];
        return Card(
          child: ListTile(
            title: Row(
              children: [
                Expanded(child: Text(item.product.name)),
                if (item.discountPercent > 0)
                  Row(children: [
                    const Icon(Icons.local_offer_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text('-${item.discountPercent.toStringAsFixed(0)}%'),
                  ]),
              ],
            ),
            subtitle: Text('Unit: ${item.unitPrice.toStringAsFixed(2)}'),
            leading: IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: () {
                final newQty = (item.quantity - 1).clamp(0.0, 1e9);
                if (newQty == 0) {
                  notifier.removeItem(item);
                } else {
                  notifier.updateQty(item, newQty);
                }
              },
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('x ${item.quantity.toStringAsFixed(0)}  '),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: () => notifier.updateQty(item, item.quantity + 1),
                ),
                const SizedBox(width: 8),
                Text(item.lineTotal.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            onTap: () async {
              final percent = await showDialog<double>(
                context: context,
                builder: (_) => _LineDiscountDialog(
                  initialPercent: item.discountPercent,
                  lineGross: item.quantity * item.unitPrice,
                ),
              );
              if (percent != null) {
                notifier.setItemDiscount(item, percent);
              }
            },
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemCount: state.cart.length,
    );
  }
}

class _BottomBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posNotifierProvider);
    final notifier = ref.read(posNotifierProvider.notifier);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal'),
                      Text(state.subtotal.toStringAsFixed(2)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tax'),
                      Text(state.tax.toStringAsFixed(2)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Builder(builder: (context) {
                    final hasLineDiscount = state.cart.any((i) => i.discountPercent > 0);
                    final lineDisc = state.cart.fold<double>(0.0, (s, i) => s + (i.quantity * i.unitPrice * (i.discountPercent.clamp(0.0, 100.0) / 100.0)));
                    final displayDiscount = hasLineDiscount ? lineDisc : state.discount;
                    final color = hasLineDiscount ? Theme.of(context).disabledColor : Theme.of(context).colorScheme.onSurface;
                    return InkWell(
                      onTap: hasLineDiscount
                          ? null
                          : () async {
                              final value = await showDialog<double>(
                                context: context,
                                builder: (_) => _DiscountDialog(
                                  initial: state.discount,
                                  preTotal: state.subtotal + state.tax,
                                ),
                              );
                              if (value != null) notifier.setDiscount(value);
                            },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Discount', style: TextStyle(color: color)),
                          Text(displayDiscount.toStringAsFixed(2), style: TextStyle(color: color)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(state.total.toStringAsFixed(2),
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: state.cart.isEmpty
                        ? null
                        : () async {
                            await notifier.holdCurrent();
                            // Extra nudge to refresh preview immediately in UI
                            await notifier.refreshPreview();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sale held')),
                              );
                            }
                          },
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                    label: const Text('Hold'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: state.cart.isEmpty
                        ? null
                        : () {
                            notifier.voidCurrent();
                          },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Void'),
                  ),
                ]),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: state.cart.isEmpty
                      ? null
                      : () async {
                          final result = await showDialog<PosCheckoutResult>(
                            context: context,
                            builder: (_) => const PaymentDialog(),
                          );
                          if (result != null && context.mounted) {
                            // Force preview refresh on successful finalize
                            await ref
                                .read(posNotifierProvider.notifier)
                                .refreshPreview();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Sale completed: ${result.saleNumber}')),
                            );
                          }
                        },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Payment'),
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(180, 48)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({required this.initial, required this.preTotal});
  final double initial; // absolute amount
  final double preTotal; // subtotal + tax to compute percent mode
  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _LineDiscountDialog extends StatefulWidget {
  const _LineDiscountDialog({required this.initialPercent, required this.lineGross});
  final double initialPercent; // percent
  final double lineGross; // qty * unit price
  @override
  State<_LineDiscountDialog> createState() => _LineDiscountDialogState();
}

enum _DiscMode { amount, percent }

class _LineDiscountDialogState extends State<_LineDiscountDialog> {
  late final TextEditingController _controller;
  _DiscMode _mode = _DiscMode.percent;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialPercent.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Item Discount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Radio<_DiscMode>(
              value: _DiscMode.amount,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
            ),
            const Text('Amount'),
            const SizedBox(width: 16),
            Radio<_DiscMode>(
              value: _DiscMode.percent,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
            ),
            const Text('Percent'),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _mode == _DiscMode.percent ? 'Discount %' : 'Discount Amount',
              prefixIcon: const Icon(Icons.local_offer_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final raw = double.tryParse(_controller.text.trim()) ?? 0.0;
            double percent;
            if (_mode == _DiscMode.percent) {
              percent = raw.clamp(0.0, 100.0);
            } else {
              final gross = widget.lineGross <= 0 ? 0.0 : widget.lineGross;
              percent = gross > 0 ? (raw / gross * 100.0) : 0.0;
              percent = percent.clamp(0.0, 100.0);
            }
            Navigator.of(context).pop(percent);
          },
          child: const Text('Apply'),
        )
      ],
    );
  }
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late final TextEditingController _controller;
  _DiscMode _mode = _DiscMode.amount;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Discount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Radio<_DiscMode>(
              value: _DiscMode.amount,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
            ),
            const Text('Amount'),
            const SizedBox(width: 16),
            Radio<_DiscMode>(
              value: _DiscMode.percent,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
            ),
            const Text('Percent'),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _mode == _DiscMode.amount ? 'Discount Amount' : 'Discount %',
              prefixIcon: const Icon(Icons.local_offer_outlined),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final raw = double.tryParse(_controller.text.trim()) ?? 0.0;
            double amount;
            if (_mode == _DiscMode.amount) {
              amount = raw;
            } else {
              final pre = widget.preTotal;
              amount = pre > 0 ? (pre * (raw / 100.0)) : 0.0;
            }
            Navigator.of(context).pop(amount.clamp(0.0, 1e12));
          },
          child: const Text('Apply'),
        )
      ],
    );
  }
}

class _HeldSalesDialog extends ConsumerStatefulWidget {
  const _HeldSalesDialog();
  @override
  ConsumerState<_HeldSalesDialog> createState() => _HeldSalesDialogState();
}

class _HeldSalesDialogState extends ConsumerState<_HeldSalesDialog> {
  bool _loading = true;
  List<HeldSaleDto> _items = const [];
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
      final list = await ref.read(posRepositoryProvider).getHeldSales();
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Held Sales'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = _items[index];
                      return ListTile(
                        title: Text(s.saleNumber),
                        subtitle: Text(
                            '${s.customerName ?? 'Walk in'} • ${s.totalAmount.toStringAsFixed(2)}'),
                        trailing: Wrap(spacing: 8, children: [
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(posNotifierProvider.notifier)
                                  .loadHeldSaleItems(s.saleId);
                              if (mounted) Navigator.of(context).pop();
                            },
                            child: const Text('Resume'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(posRepositoryProvider)
                                  .voidSale(s.saleId);
                              // After voiding, refresh the receipt preview on POS
                              await ref
                                  .read(posNotifierProvider.notifier)
                                  .refreshPreview();
                              await _load();
                            },
                            child: const Text('Void'),
                          ),
                        ]),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close')),
      ],
    );
  }
}
