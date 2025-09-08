import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/customer_repository.dart';

class CustomerEditPage extends ConsumerStatefulWidget {
  const CustomerEditPage({super.key, required this.customerId});
  final int customerId;
  @override
  ConsumerState<CustomerEditPage> createState() => _CustomerEditPageState();
}

class _CustomerEditPageState extends ConsumerState<CustomerEditPage> {
  CustomerDto? _customer;
  bool _loading = true;
  bool _saving = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _tax = TextEditingController();
  final _terms = TextEditingController();
  final _credit = TextEditingController();
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(customerRepositoryProvider);
    final cust = await repo.getCustomer(widget.customerId);
    setState(() {
      _customer = cust;
      _name.text = cust.name;
      _phone.text = cust.phone ?? '';
      _email.text = cust.email ?? '';
      _address.text = cust.address ?? '';
      _tax.text = cust.taxNumber ?? '';
      _terms.text = cust.paymentTerms.toString();
      _credit.text = cust.creditLimit.toString();
      _active = cust.isActive;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _tax.dispose();
    _terms.dispose();
    _credit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.updateCustomer(
        customerId: widget.customerId,
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        taxNumber: _tax.text.trim().isEmpty ? null : _tax.text.trim(),
        paymentTerms: int.tryParse(_terms.text.trim()),
        creditLimit: double.tryParse(_credit.text.trim()),
        isActive: _active,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Customer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 8),
                TextField(controller: _tax, decoration: const InputDecoration(labelText: 'Tax Number')),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: _terms, decoration: const InputDecoration(labelText: 'Payment Terms (days)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _credit, decoration: const InputDecoration(labelText: 'Credit Limit'), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 8),
                SwitchListTile(value: _active, onChanged: (v) => setState(() => _active = v), title: const Text('Active')),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_rounded), label: const Text('Save')),
              ],
            ),
    );
  }
}

