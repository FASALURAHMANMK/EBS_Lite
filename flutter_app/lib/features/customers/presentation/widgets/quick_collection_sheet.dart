import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../data/customer_repository.dart';
import '../../data/models.dart';

Future<bool?> showQuickCollectionSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _QuickCollectionSheet(),
  );
}

class _QuickCollectionSheet extends ConsumerStatefulWidget {
  const _QuickCollectionSheet();

  @override
  ConsumerState<_QuickCollectionSheet> createState() =>
      _QuickCollectionSheetState();
}

class _QuickCollectionSheetState extends ConsumerState<_QuickCollectionSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<CustomerDto> _customers = const [];
  List<Map<String, dynamic>> _paymentMethods = const [];

  CustomerDto? _customer;
  int? _paymentMethodId;

  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(customerRepositoryProvider);
      final results = await Future.wait([
        repo.getCustomers(),
        repo.getPaymentMethods(),
      ]);
      final customers = results[0] as List<CustomerDto>;
      final methods = results[1] as List<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _paymentMethods = methods;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCustomer() async {
    final picked = await showDialog<CustomerDto>(
      context: context,
      builder: (_) => _CustomerPickerDialog(customers: _customers),
    );
    if (!mounted || picked == null) return;
    setState(() => _customer = picked);
  }

  Future<void> _save() async {
    final customer = _customer;
    if (customer == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Select a customer')));
      return;
    }
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.createCollection(
        customerId: customer.customerId,
        amount: amount,
        paymentMethodId: _paymentMethodId,
        reference:
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Collection recorded')));
    } on OutboxQueuedException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: _loading
          ? const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            )
          : (_error != null)
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Text(_error!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payments_rounded),
                        const SizedBox(width: 8),
                        Text('Quick Collection',
                            style: theme.textTheme.titleMedium),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      child: ListTile(
                        leading: const Icon(Icons.person_rounded),
                        title: Text(_customer?.name ?? 'Select customer'),
                        subtitle: Text((_customer?.phone ?? '').isEmpty
                            ? 'Tap to choose'
                            : _customer!.phone!),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _pickCustomer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _paymentMethodId,
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Payment method (optional)'),
                        ),
                        ..._paymentMethods.map((m) {
                          final id = (m['method_id'] as int?) ?? 0;
                          final name = (m['name'] ?? '').toString();
                          return DropdownMenuItem<int>(
                            value: id == 0 ? null : id,
                            child: Text(name.isEmpty ? 'Method #$id' : name),
                          );
                        }),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _paymentMethodId = v),
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        prefixIcon: Icon(Icons.credit_card_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reference,
                      decoration: const InputDecoration(
                        labelText: 'Reference (optional)',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notes,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text('Save Collection'),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _CustomerPickerDialog extends StatefulWidget {
  const _CustomerPickerDialog({required this.customers});
  final List<CustomerDto> customers;

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.customers
        : widget.customers.where((c) {
            final hay =
                '${c.name} ${c.phone ?? ''} ${c.email ?? ''}'.toLowerCase();
            return hay.contains(q);
          }).toList();

    return AlertDialog(
      title: const Text('Select customer'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search name/phone/email',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: filtered.isEmpty
                  ? const Center(child: Text('No customers'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return ListTile(
                          leading: const Icon(Icons.person_rounded),
                          title: Text(c.name),
                          subtitle: Text(
                            [c.phone, c.email]
                                .whereType<String>()
                                .where((s) => s.trim().isNotEmpty)
                                .join(' • '),
                          ),
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
