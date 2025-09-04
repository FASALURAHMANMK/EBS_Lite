import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/controllers/location_notifier.dart';
import '../../data/inventory_repository.dart';
import '../../../../core/error_handler.dart';
import '../../data/models.dart';

class StockTransferViewPage extends ConsumerStatefulWidget {
  const StockTransferViewPage({super.key, required this.transferId});
  final int transferId;

  @override
  ConsumerState<StockTransferViewPage> createState() => _StockTransferViewPageState();
}

class _StockTransferViewPageState extends ConsumerState<StockTransferViewPage> {
  late Future<StockTransferDetailDto> _future;
  @override
  void initState() {
    super.initState();
    _future = ref.read(inventoryRepositoryProvider).getStockTransfer(widget.transferId);
  }

  Future<void> _refresh() async {
    setState(() { _future = ref.read(inventoryRepositoryProvider).getStockTransfer(widget.transferId); });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer Details')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<StockTransferDetailDto>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator(minHeight: 2);
            if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load: ${snapshot.error}', style: TextStyle(color: theme.colorScheme.error)),
              ));
            }
            final t = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _Header(t: t),
                const SizedBox(height: 12),
                _Actions(t: t, onChanged: _refresh),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ListTile(title: Text('Items')),
                      const Divider(height: 1),
                      ...t.items.map((it) => ListTile(
                        title: Text(it.productName),
                        subtitle: Text('Qty: ${it.quantity} ${it.unitSymbol ?? ''}${(it.productSku ?? '').isNotEmpty ? ' · SKU: ${it.productSku}' : ''}'),
                      )),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.t});
  final StockTransferDetailDto t;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text('${t.transferNumber} • ${t.status.replaceAll('_', ' ')}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text('${t.fromLocationName} → ${t.toLocationName}\n${t.transferDate.toLocal()}'),
        isThreeLine: true,
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.t, required this.onChanged});
  final StockTransferDetailDto t;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(inventoryRepositoryProvider);
    final locId = ref.watch(locationNotifierProvider).selected?.locationId;
    final isIncoming = locId != null && t.toLocationId == locId && t.fromLocationId != locId;
    final isOutgoing = locId != null && t.fromLocationId == locId && t.toLocationId != locId;
    // Correct role gating:
    // - Approve (dispatch) must be done by source (outgoing) location when Pending
    // - Receive (complete) must be done by destination (incoming) location when In Transit
    // - Cancel is allowed by source (outgoing) location while Pending
    final canApprove = t.status == 'PENDING' && isOutgoing;
    final canComplete = t.status == 'IN_TRANSIT' && isIncoming;
    final canCancel = t.status == 'PENDING' && isOutgoing;

    Future<void> _do(Future<void> Function() f, String ok) async {
      try {
        await f();
        await onChanged();
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(ok)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('Failed: ${ErrorHandler.message(e)}')));
        }
      }
    }

    return Wrap(
      spacing: 8,
      children: [
        if (canApprove)
          FilledButton.icon(
            onPressed: () => _do(() => repo.approveStockTransfer(t.transferId), 'Approved'),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Approve (Dispatch)')),
        if (canComplete)
          FilledButton.icon(
            onPressed: () => _do(() => repo.completeStockTransfer(t.transferId), 'Completed'),
            icon: const Icon(Icons.inventory_rounded),
            label: const Text('Receive')),
        if (canCancel)
          TextButton.icon(
            onPressed: () => _do(() => repo.cancelStockTransfer(t.transferId), 'Cancelled'),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel')),
      ],
    );
  }
}
