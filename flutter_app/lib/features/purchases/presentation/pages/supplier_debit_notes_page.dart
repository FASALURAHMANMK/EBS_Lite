import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/error_handler.dart';
import '../../data/models.dart';
import '../../data/purchases_repository.dart';
import 'supplier_debit_note_form_page.dart';

class SupplierDebitNotesPage extends ConsumerStatefulWidget {
  const SupplierDebitNotesPage({super.key});

  @override
  ConsumerState<SupplierDebitNotesPage> createState() =>
      _SupplierDebitNotesPageState();
}

class _SupplierDebitNotesPageState
    extends ConsumerState<SupplierDebitNotesPage> {
  bool _loading = true;
  final _search = TextEditingController();
  List<PurchaseCostAdjustmentDto> _items = const [];

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list =
          await ref.read(purchasesRepositoryProvider).getSupplierDebitNotes();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _items
        : _items.where((item) {
            return item.adjustmentNumber.toLowerCase().contains(query) ||
                (item.supplierName ?? '').toLowerCase().contains(query);
          }).toList();
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Supplier Debit Notes'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const SupplierDebitNoteFormPage(),
            ),
          );
          if (created == true && mounted) {
            _load();
          }
        },
        tooltip: 'Create Debit Note',
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by note number or supplier',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _load,
                  ),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  : filtered.isEmpty
                      ? const Center(child: Text('No supplier debit notes'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading:
                                    const Icon(Icons.assignment_return_rounded),
                                title: Text(item.adjustmentNumber),
                                subtitle: Text(
                                  [
                                    if ((item.supplierName ?? '').isNotEmpty)
                                      item.supplierName!,
                                    _formatDate(item.adjustmentDate),
                                  ].join(' • '),
                                ),
                                trailing: Text(
                                  item.totalAmount.abs().toStringAsFixed(2),
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemCount: filtered.length,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
