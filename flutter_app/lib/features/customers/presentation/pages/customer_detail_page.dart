import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/customer_repository.dart';
import 'customer_edit_page.dart';
import '../../../loyalty/data/loyalty_repository.dart';
import '../../../../core/error_handler.dart';

class CustomerDetailPage extends ConsumerStatefulWidget {
  const CustomerDetailPage({super.key, required this.customerId});
  final int customerId;
  @override
  ConsumerState<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends ConsumerState<CustomerDetailPage> {
  late Future<CustomerDto> _customerFuture;
  late Future<CustomerSummaryDto> _summaryFuture;
  late Future<List<LoyaltyTierDto>> _tiersFuture;
  late Future<LoyaltySettingsDto> _loySettingsFuture;
  late Future<List<Map<String, dynamic>>> _salesFuture;
  late Future<List<Map<String, dynamic>>> _returnsFuture;
  late Future<List<CustomerCollectionDto>> _collectionsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(customerRepositoryProvider);
    _customerFuture = repo.getCustomer(widget.customerId);
    _summaryFuture = repo.getCustomerSummary(widget.customerId);
    final loyRepo = ref.read(loyaltyRepositoryProvider);
    _tiersFuture = loyRepo.getTiers();
    _loySettingsFuture = loyRepo.getSettings();
    _salesFuture = repo.getSales(customerId: widget.customerId);
    _returnsFuture = repo.getSaleReturns(customerId: widget.customerId);
    _collectionsFuture = repo.getCollections(customerId: widget.customerId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer'),
        actions: [
          IconButton(
            tooltip: 'Record Collection',
            icon: const Icon(Icons.payments_rounded),
            onPressed: () => _showCollectSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await Future.wait([
            _customerFuture,
            _summaryFuture,
            _salesFuture,
            _returnsFuture,
            _collectionsFuture
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            FutureBuilder<CustomerDto>(
              future: _customerFuture,
              builder: (context, s) {
                if (!s.hasData) {
                  return const LinearProgressIndicator(minHeight: 2);
                }
                final cu = s.data!;
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cu.name,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text([
                                    if ((cu.phone ?? '').isNotEmpty) 'Phone: ${cu.phone}',
                                    if ((cu.email ?? '').isNotEmpty) 'Email: ${cu.email}',
                                    if ((cu.address ?? '').isNotEmpty) 'Address: ${cu.address}',
                                    if ((cu.taxNumber ?? '').isNotEmpty) 'Tax#: ${cu.taxNumber}',
                                    'Credit Limit: ${cu.creditLimit.toStringAsFixed(2)} | Terms: ${cu.paymentTerms} days',
                                  ].join('\n')),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                final updated = await Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => CustomerEditPage(customerId: cu.customerId)),
                                );
                                if (updated == true && mounted) _reload();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<LoyaltyTierDto>>(
                          future: _tiersFuture,
                          builder: (context, ts) {
                            if (!ts.hasData) return const SizedBox.shrink();
                            final tiers = ts.data!;
                            final tierName = tiers.firstWhere(
                              (t) => t.tierId == (cu.loyaltyTierId ?? -1),
                              orElse: () => LoyaltyTierDto(tierId: -1, name: 'Member', minPoints: 0, isActive: true),
                            ).name;
                            return Wrap(spacing: 8, runSpacing: 4, children: [
                              if (cu.isLoyalty) Chip(label: Text('Tier: $tierName')),
                              FutureBuilder<CustomerSummaryDto>(
                                future: _summaryFuture,
                                builder: (context, ss) {
                                  if (!ss.hasData) return const SizedBox.shrink();
                                  final pts = ss.data!.loyaltyPoints;
                                  return Row(mainAxisSize: MainAxisSize.min, children: [
                                    Chip(label: Text('Points: ${pts.toStringAsFixed(0)}')),
                                    const SizedBox(width: 6),
                                    FutureBuilder<LoyaltySettingsDto>(
                                      future: _loySettingsFuture,
                                      builder: (context, ls) {
                                        if (!ls.hasData) return const SizedBox.shrink();
                                        final avail = (pts - ls.data!.minPointsReserve).clamp(0, double.infinity);
                                        return Chip(label: Text('Avail: ${avail.toStringAsFixed(0)}'));
                                      },
                                    ),
                                  ]);
                                },
                              ),
                            ]);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Credit balance and available credit
            FutureBuilder<CustomerDto>(
              future: _customerFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final cu = s.data!;
                final outstanding = cu.creditBalance;
                final available = (cu.creditLimit - cu.creditBalance);
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _metric(
                            'Outstanding', outstanding < 0 ? 0 : outstanding),
                        _metric(
                            'Available Credit', available < 0 ? 0 : available),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder<CustomerSummaryDto>(
              future: _summaryFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final sum = s.data!;
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _metric('Sales', sum.totalSales),
                        _metric('Payments', sum.totalPayments),
                        _metric('Returns', sum.totalReturns),
                        _metric('Loyalty', sum.loyaltyPoints),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Sales'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _salesFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final items = s.data!;
                return _simpleList(
                  items
                      .map((e) => _SimpleRow(
                            title: (e['sale_number'] ?? e['number'] ?? '')
                                .toString(),
                            subtitle: (e['status'] ?? '').toString(),
                            trailing: (e['total_amount'] ?? 0).toString(),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Sale Returns'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _returnsFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final items = s.data!;
                return _simpleList(
                  items
                      .map((e) => _SimpleRow(
                            title: (e['return_number'] ?? e['number'] ?? '')
                                .toString(),
                            subtitle: (e['status'] ?? '').toString(),
                            trailing: (e['total_amount'] ?? 0).toString(),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            _sectionTitle('Collections'),
            FutureBuilder<List<CustomerCollectionDto>>(
              future: _collectionsFuture,
              builder: (context, s) {
                if (!s.hasData) return const SizedBox.shrink();
                final items = s.data!;
                return _simpleList(
                  items
                      .map((p) => _SimpleRow(
                            title: p.collectionNumber,
                            subtitle: p.collectionDate.toLocal().toString(),
                            trailing: p.amount.toStringAsFixed(2),
                          ))
                      .toList(),
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
          Text(value.toStringAsFixed(2),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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

extension on num {
  String toMoney() => toStringAsFixed(2);
}

void _showError(BuildContext context, Object e) {
  final msg = ErrorHandler.message(e);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

void _showInfo(BuildContext context, String m) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

extension _Collect on _CustomerDetailPageState {
  Future<void> _showCollectSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CollectSheet(
          customerId: widget.customerId,
          onDone: () {
            _reload();
          }),
    );
  }
}

class _CollectSheet extends ConsumerStatefulWidget {
  const _CollectSheet({required this.customerId, required this.onDone});
  final int customerId;
  final VoidCallback onDone;
  @override
  ConsumerState<_CollectSheet> createState() => _CollectSheetState();
}

class _CollectSheetState extends ConsumerState<_CollectSheet> {
  final _amount = TextEditingController();
  final _date = ValueNotifier<DateTime>(DateTime.now());
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _invoiceMode = false;
  bool _saving = false;
  List<Map<String, dynamic>> _methods = const [];
  int? _methodId;
  String? _methodName;
  List<Map<String, dynamic>> _invoices = const [];
  final Map<int, TextEditingController> _alloc = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final repo = ref.read(customerRepositoryProvider);
      final methods = await repo.getPaymentMethods();
      setState(() {
        _methods = methods;
        _methodId = methods.isNotEmpty
            ? (methods.first['method_id'] as int? ??
                methods.first['id'] as int?)
            : null;
        _methodName = methods.isNotEmpty
            ? ((methods.first['name'] ?? methods.first['method'])?.toString())
            : null;
      });
    } catch (e) {
      _showError(context, e);
    }
  }

  Future<void> _loadInvoices() async {
    try {
      final repo = ref.read(customerRepositoryProvider);
      final list =
          await repo.getOutstandingInvoices(customerId: widget.customerId);
      final invoices = list
          .where((e) =>
              ((e['total_amount'] ?? 0) as num).toDouble() -
                  ((e['paid_amount'] ?? 0) as num).toDouble() >
              0.0)
          .toList();
      setState(() {
        _invoices = invoices;
        for (final inv in invoices) {
          final id = inv['sale_id'] as int?;
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
    for (final c in _alloc.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _amountVal => double.tryParse(_amount.text.trim()) ?? 0;

  double _invoiceOutstanding(Map<String, dynamic> inv) {
    final total = (inv['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
    return (total - paid).clamp(0, double.infinity);
  }

  void _autoAllocate() {
    var remaining = _amountVal;
    for (final inv in _invoices) {
      final id = inv['sale_id'] as int;
      final out = _invoiceOutstanding(inv);
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
    List<Map<String, dynamic>>? invoices;
    if (_invoiceMode) {
      final lines = <Map<String, dynamic>>[];
      double sum = 0;
      for (final inv in _invoices) {
        final id = inv['sale_id'] as int;
        final txt = _alloc[id]?.text.trim() ?? '';
        if (txt.isEmpty) continue;
        final val = double.tryParse(txt) ?? 0;
        if (val <= 0) continue;
        final out = _invoiceOutstanding(inv);
        if (val > out) {
          _showInfo(context,
              'Allocation for ${inv['sale_number']} exceeds outstanding');
          return;
        }
        lines.add({'sale_id': id, 'amount': val});
        sum += val;
      }
      if (lines.isEmpty) {
        _showInfo(context, 'Allocate amount to at least one invoice');
        return;
      }
      if ((sum - amt).abs() > 0.009) {
        _showInfo(context,
            'Allocated total (${sum.toStringAsFixed(2)}) must equal amount (${amt.toStringAsFixed(2)})');
        return;
      }
      invoices = lines;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.createCollection(
        customerId: widget.customerId,
        amount: amt,
        paymentMethodId: _methodId,
        receivedDate: _date.value,
        reference:
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        invoices: invoices,
        skipAutoAllocation: !_invoiceMode,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDone();
      _showInfo(context, 'Collection recorded');
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
                  const Text('Record Collection',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Left: toggle + label
                  Row(
                    children: [
                      Switch(
                        value: _invoiceMode,
                        onChanged: (v) async {
                          setState(() => _invoiceMode = v);
                          if (v && _invoices.isEmpty) {
                            await _loadInvoices();
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
                  // Right: date label + icon + value (tap anywhere to pick)
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 6.0),
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
                                  final id = (m['method_id'] as int?) ??
                                      (m['id'] as int?);
                                  final name = (m['name'] ?? m['method'] ?? '')
                                      .toString();
                                  return RadioListTile<int>(
                                    value: id ?? -1,
                                    groupValue: _methodId ?? -1,
                                    onChanged: (v) => Navigator.of(ctx)
                                        .pop({'id': id, 'name': name}),
                                    title: Text(name),
                                  );
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancel')),
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
              // Optional reference to help reconcile (e.g., cheque no., bank txn)
              TextField(
                  controller: _reference,
                  decoration: const InputDecoration(labelText: 'Reference')),
              const SizedBox(height: 8),
              TextField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'Notes')),
              const SizedBox(height: 8),
              if (_invoiceMode) ...[
                Row(
                  children: [
                    const Text('Outstanding Invoices',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                        onPressed: _autoAllocate,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Auto allocate')),
                  ],
                ),
                const SizedBox(height: 4),
                ..._invoices.map((inv) {
                  final saleNo = (inv['sale_number'] ?? '').toString();
                  final out = _invoiceOutstanding(inv);
                  final id = inv['sale_id'] as int;
                  return ListTile(
                    title: Text(saleNo),
                    subtitle: Text('Outstanding: ${out.toMoney()}'),
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
                  label: Text(_saving ? 'Saving...' : 'Record Collection'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleRow {
  final String title;
  final String? subtitle;
  final String? trailing;
  _SimpleRow({required this.title, this.subtitle, this.trailing});
}
