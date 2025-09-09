import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/supplier_repository.dart';
import 'supplier_edit_page.dart';

class SupplierDetailPage extends ConsumerStatefulWidget {
  const SupplierDetailPage({super.key, required this.supplierId});
  final int supplierId;
  @override
  ConsumerState<SupplierDetailPage> createState() => _SupplierDetailPageState();
}

class _SupplierDetailPageState extends ConsumerState<SupplierDetailPage> {
  late Future<SupplierDto> _supplierFuture;
  late Future<SupplierSummaryDto> _summaryFuture;
  late Future<List<Map<String, dynamic>>> _purchasesFuture;
  late Future<List<Map<String, dynamic>>> _returnsFuture;
  late Future<List<SupplierPaymentDto>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(supplierRepositoryProvider);
    _supplierFuture = repo.getSupplier(widget.supplierId);
    _summaryFuture = repo.getSupplierSummary(widget.supplierId);
    _purchasesFuture = repo.getPurchases(supplierId: widget.supplierId);
    _returnsFuture = repo.getPurchaseReturns(supplierId: widget.supplierId);
    _paymentsFuture = repo.getPayments(supplierId: widget.supplierId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier'),
        actions: [
          IconButton(
            tooltip: 'Record Payment',
            icon: const Icon(Icons.payments_rounded),
            onPressed: () => _showPaymentSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await Future.wait([
            _supplierFuture, _summaryFuture, _purchasesFuture, _returnsFuture, _paymentsFuture
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            FutureBuilder<SupplierDto>(
              future: _supplierFuture,
              builder: (context, s) {
                if (!s.hasData) return const LinearProgressIndicator(minHeight: 2);
                final sup = s.data!;
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(sup.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if ((sup.contactPerson ?? '').isNotEmpty) 'Contact: ${sup.contactPerson}',
                      if ((sup.phone ?? '').isNotEmpty) 'Phone: ${sup.phone}',
                      if ((sup.email ?? '').isNotEmpty) 'Email: ${sup.email}',
                      if ((sup.address ?? '').isNotEmpty) 'Address: ${sup.address}',
                      'Credit Limit: ${sup.creditLimit.toStringAsFixed(2)} | Terms: ${sup.paymentTerms} days',
                    ].join('\n')),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final updated = await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SupplierEditPage(supplierId: sup.supplierId)),
                        );
                        if (updated == true && mounted) _reload();
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder<SupplierSummaryDto>(
              future: _summaryFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final sum = s.data!;
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _metric('Purchased', sum.totalPurchases),
                        _metric('Payments', sum.totalPayments),
                        _metric('Returns', sum.totalReturns),
                        _metric('Balance', sum.outstandingBalance),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Purchases'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _purchasesFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final items = s.data!;
                return _simpleList(
                  items.map((e) => _SimpleRow(
                    title: (e['purchase_number'] ?? e['number'] ?? '').toString(),
                    subtitle: (e['status'] ?? '').toString(),
                    trailing: (e['total_amount'] ?? 0).toString(),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Purchase Returns'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _returnsFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final items = s.data!;
                return _simpleList(
                  items.map((e) => _SimpleRow(
                    title: (e['return_number'] ?? e['number'] ?? '').toString(),
                    subtitle: (e['status'] ?? '').toString(),
                    trailing: (e['total_amount'] ?? 0).toString(),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Payments'),
            FutureBuilder<List<SupplierPaymentDto>>(
              future: _paymentsFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final items = s.data!;
                return _simpleList(
                  items.map((p) => _SimpleRow(
                    title: p.paymentNumber,
                    subtitle: p.paymentDate.toLocal().toString(),
                    trailing: p.amount.toStringAsFixed(2),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _metric(String label, double value) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      );

  Widget _simpleList(List<_SimpleRow> rows) => Card(
        elevation: 0,
        child: Column(
          children: rows
              .map((r) => ListTile(
                    title: Text(r.title),
                    subtitle: r.subtitle != null ? Text(r.subtitle!) : null,
                    trailing: Text(r.trailing ?? ''),
                  ))
              .toList(),
        ),
      );
}

class _SimpleRow {
  final String title;
  final String? subtitle;
  final String? trailing;
  _SimpleRow({required this.title, this.subtitle, this.trailing});
}

void _showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(e.toString())));
}

void _showInfo(BuildContext context, String m) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

extension _Pay on _SupplierDetailPageState {
  Future<void> _showPaymentSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaySheet(
        supplierId: widget.supplierId,
        onDone: () {
          _reload();
        },
      ),
    );
  }
}

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({required this.supplierId, required this.onDone});
  final int supplierId;
  final VoidCallback onDone;
  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  final _amount = TextEditingController();
  final _date = ValueNotifier<DateTime>(DateTime.now());
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _invoiceMode = false;
  bool _saving = false;
  List<Map<String, dynamic>> _methods = const [];
  int? _methodId;
  String? _methodName;
  List<Map<String, dynamic>> _purchases = const [];
  final Map<int, TextEditingController> _alloc = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final repo = ref.read(supplierRepositoryProvider);
      final methods = await repo.getPaymentMethods();
      setState(() {
        _methods = methods;
        _methodId = methods.isNotEmpty
            ? (methods.first['method_id'] as int? ?? methods.first['id'] as int?)
            : null;
        _methodName = methods.isNotEmpty
            ? ((methods.first['name'] ?? methods.first['method'])?.toString())
            : null;
      });
    } catch (e) {
      _showError(context, e);
    }
  }

  Future<void> _loadPurchases() async {
    try {
      final repo = ref.read(supplierRepositoryProvider);
      final list = await repo.getOutstandingPurchases(supplierId: widget.supplierId);
      final purchases = list
          .where((e) =>
              ((e['total_amount'] ?? 0) as num).toDouble() -
                  ((e['paid_amount'] ?? 0) as num).toDouble() >
              0.0)
          .toList();
      setState(() {
        _purchases = purchases;
        for (final inv in purchases) {
          final id = inv['purchase_id'] as int?;
          if (id != null && !_alloc.containsKey(id)) {
            _alloc[id] = TextEditingController();
          }
        }
      });
      if (_invoiceMode) _autoAllocate();
    } catch (e) {
      _showError(context, e);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    for (final c in _alloc.values) c.dispose();
    super.dispose();
  }

  double get _amountVal => double.tryParse(_amount.text.trim()) ?? 0;

  double _purchaseOutstanding(Map<String, dynamic> inv) {
    final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
    return (total - paid).clamp(0, double.infinity);
  }

  void _autoAllocate() {
    var remaining = _amountVal;
    for (final inv in _purchases) {
      final id = inv['purchase_id'] as int;
      final out = _purchaseOutstanding(inv);
      if (remaining <= 0) {
        _alloc[id]?.text = '';
        continue;
      }
      final alloc = remaining >= out ? out : remaining;
      _alloc[id]?.text = alloc > 0 ? alloc.toStringAsFixed(2) : '';
      remaining -= alloc;
    }
    setState(() {});
  }

  Future<void> _submit() async {
    final amt = _amountVal;
    if (amt <= 0) {
      _showInfo(context, 'Enter a valid amount');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(supplierRepositoryProvider);

      if (_invoiceMode) {
        // Gather allocations and create one payment per purchase allocation
        final lines = <Map<String, dynamic>>[];
        double sum = 0;
        for (final inv in _purchases) {
          final id = inv['purchase_id'] as int;
          final txt = _alloc[id]?.text.trim() ?? '';
          if (txt.isEmpty) continue;
          final val = double.tryParse(txt) ?? 0;
          if (val <= 0) continue;
          final out = _purchaseOutstanding(inv);
          if (val > out) {
            _showInfo(context, 'Allocation for ${inv['purchase_number']} exceeds outstanding');
            setState(() => _saving = false);
            return;
          }
          lines.add({'purchase_id': id, 'amount': val});
          sum += val;
        }
        if (lines.isEmpty) {
          _showInfo(context, 'Allocate amount to at least one purchase');
          setState(() => _saving = false);
          return;
        }
        if ((sum - amt).abs() > 0.009) {
          _showInfo(context, 'Allocated total (${sum.toStringAsFixed(2)}) must equal amount (${amt.toStringAsFixed(2)})');
          setState(() => _saving = false);
          return;
        }
        for (final l in lines) {
          await repo.createPayment(
            supplierId: widget.supplierId,
            purchaseId: l['purchase_id'] as int,
            amount: (l['amount'] as num).toDouble(),
            paymentMethodId: _methodId,
            paymentDate: _date.value,
            reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
        }
      } else {
        // Record a general supplier payment
        await repo.createPayment(
          supplierId: widget.supplierId,
          amount: amt,
          paymentMethodId: _methodId,
          paymentDate: _date.value,
          reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDone();
      _showInfo(context, 'Payment recorded');
    } catch (e) {
      _showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payments_rounded),
                  const SizedBox(width: 8),
                  const Text('Record Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Row(
                    children: [
                      Switch(
                        value: _invoiceMode,
                        onChanged: (v) async {
                          setState(() => _invoiceMode = v);
                          if (v && _purchases.isEmpty) {
                            await _loadPurchases();
                          } else if (v) {
                            _autoAllocate();
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      const Text('Apply to invoices'),
                    ],
                  ),
                  const Spacer(),
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _date,
                    builder: (context, d, _) => InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: d,
                          firstDate: DateTime(now.year - 5),
                          lastDate: DateTime(now.year + 5),
                        );
                        if (picked != null) _date.value = picked;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text('${d.toLocal()}'.split(' ').first),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
                onChanged: (_) {
                  if (_invoiceMode) _autoAllocate();
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Payment Method'),
                subtitle: Text(_methodName ?? 'Select'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _methods.isEmpty
                    ? null
                    : () async {
                        final picked = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Select Payment Method'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _methods.length,
                                itemBuilder: (_, i) {
                                  final m = _methods[i];
                                  final id = (m['method_id'] as int?) ?? (m['id'] as int?);
                                  final name = (m['name'] ?? m['method'] ?? '').toString();
                                  return RadioListTile<int>(
                                    value: id ?? -1,
                                    groupValue: _methodId ?? -1,
                                    onChanged: (v) => Navigator.of(ctx).pop({'id': id, 'name': name}),
                                    title: Text(name),
                                  );
                                },
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                            ],
                          ),
                        );
                        if (picked != null) {
                          setState(() {
                            _methodId = picked['id'] as int?;
                            _methodName = picked['name'] as String?;
                          });
                        }
                      },
              ),
              const SizedBox(height: 8),
              TextField(controller: _reference, decoration: const InputDecoration(labelText: 'Reference')), 
              const SizedBox(height: 8),
              TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 8),
              if (_invoiceMode) ...[
                Row(
                  children: [
                    const Text('Outstanding Purchases', style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(onPressed: _autoAllocate, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Auto allocate')),
                  ],
                ),
                const SizedBox(height: 4),
                ..._purchases.map((inv) {
                  final no = (inv['purchase_number'] ?? '').toString();
                  final out = _purchaseOutstanding(inv);
                  final id = inv['purchase_id'] as int;
                  return ListTile(
                    title: Text(no),
                    subtitle: Text('Outstanding: ${out.toStringAsFixed(2)}'),
                    trailing: SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _alloc[id],
                        decoration: const InputDecoration(hintText: 'Amount'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving...' : 'Record Payment'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
