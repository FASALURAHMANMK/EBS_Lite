import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/controllers/location_notifier.dart';
import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import 'stock_transfer_form_page.dart';
import 'stock_transfer_view_page.dart';

class StockTransfersPage extends ConsumerStatefulWidget {
  const StockTransfersPage({super.key});
  @override
  ConsumerState<StockTransfersPage> createState() => _StockTransfersPageState();
}

class _StockTransfersPageState extends ConsumerState<StockTransfersPage> {
  String _status = 'ALL'; // ALL, PENDING, IN_TRANSIT, COMPLETED, CANCELLED
  String _direction = 'ALL'; // ALL, INCOMING, OUTGOING
  late Future<List<StockTransferListItemDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<StockTransferListItemDto>> _load() async {
    final loc = ref.read(locationNotifierProvider).selected;
    final repo = ref.read(inventoryRepositoryProvider);
    final locationId = loc?.locationId;
    int? src; int? dst;
    switch (_direction) {
      case 'INCOMING':
        dst = locationId;
        break;
      case 'OUTGOING':
        src = locationId;
        break;
    }
    final status = _status == 'ALL' ? null : _status;
    return repo.getStockTransfers(
      locationId: (_direction == 'ALL') ? locationId : null,
      sourceLocationId: src,
      destinationLocationId: dst,
      status: status,
    );
  }

  Future<void> _refresh() async {
    setState(() { _future = _load(); });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Transfers'),
        actions: [
          IconButton(
            tooltip: 'New Transfer',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final created = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StockTransferFormPage()),
              );
              if (created == true) await _refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Status:'),
                for (final s in ['ALL','PENDING','IN_TRANSIT','COMPLETED','CANCELLED'])
                  ChoiceChip(
                    label: Text(s.replaceAll('_', ' ')),
                    selected: _status == s,
                    onSelected: (_) => setState(() { _status = s; _future = _load(); }),
                  ),
                const SizedBox(width: 16),
                const Text('Direction:'),
                for (final d in ['ALL','INCOMING','OUTGOING'])
                  ChoiceChip(
                    label: Text(d),
                    selected: _direction == d,
                    onSelected: (_) => setState(() { _direction = d; _future = _load(); }),
                  ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Request Stock'),
                  onPressed: () async {
                    final created = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StockTransferFormPage(mode: TransferMode.request)),
                    );
                    if (created == true) await _refresh();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<StockTransferListItemDto>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator(minHeight: 2);
                  }
                  if (snapshot.hasError) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Failed to load transfers: ${snapshot.error}', style: TextStyle(color: theme.colorScheme.error)),
                    ));
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) return const Center(child: Text('No transfers'));
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _TransferTile(item: items[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferTile extends ConsumerWidget {
  const _TransferTile({required this.item});
  final StockTransferListItemDto item;

  Color _statusColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (item.status) {
      case 'PENDING':
        return theme.colorScheme.secondaryContainer;
      case 'IN_TRANSIT':
        return Colors.orange.shade200;
      case 'COMPLETED':
        return Colors.green.shade200;
      case 'CANCELLED':
        return theme.colorScheme.errorContainer;
      default:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final meLoc = ref.watch(locationNotifierProvider).selected?.locationId;
    final incoming = meLoc != null && item.toLocationId == meLoc && item.fromLocationId != meLoc;
    final outgoing = meLoc != null && item.fromLocationId == meLoc && item.toLocationId != meLoc;
    return ListTile(
      tileColor: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: _statusColor(context), borderRadius: BorderRadius.circular(999)),
          child: Text(item.status.replaceAll('_', ' '), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(item.transferNumber, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
      ]),
      subtitle: Text('${item.fromLocationName} → ${item.toLocationName} • ${item.transferDate.toLocal()}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (incoming) const Icon(Icons.call_received_rounded) else if (outgoing) const Icon(Icons.call_made_rounded),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StockTransferViewPage(transferId: item.transferId)));
      },
    );
  }
}
