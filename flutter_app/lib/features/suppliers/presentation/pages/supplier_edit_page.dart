import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supplier_repository.dart';

class SupplierEditPage extends ConsumerStatefulWidget {
  const SupplierEditPage({super.key, required this.supplierId});
  final int supplierId;
  @override
  ConsumerState<SupplierEditPage> createState() => _SupplierEditPageState();
}

class _SupplierEditPageState extends ConsumerState<SupplierEditPage> {
  bool _loading = true;
  bool _saving = false;
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _terms = TextEditingController();
  final _credit = TextEditingController();
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(supplierRepositoryProvider);
    final sup = await repo.getSupplier(widget.supplierId);
    setState(() {
      _name.text = sup.name;
      _contact.text = sup.contactPerson ?? '';
      _phone.text = sup.phone ?? '';
      _email.text = sup.email ?? '';
      _address.text = sup.address ?? '';
      _terms.text = sup.paymentTerms.toString();
      _credit.text = sup.creditLimit.toString();
      _active = sup.isActive;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _terms.dispose();
    _credit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(supplierRepositoryProvider);
      await repo.updateSupplier(
        supplierId: widget.supplierId,
        name: _name.text.trim(),
        contact: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
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
      appBar: AppBar(title: const Text('Edit Supplier')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Contact Person')),
                const SizedBox(height: 8),
                TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 8),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
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

