import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/customer_repository.dart';

class CustomerCreatePage extends ConsumerStatefulWidget {
  const CustomerCreatePage({super.key});
  @override
  ConsumerState<CustomerCreatePage> createState() => _CustomerCreatePageState();
}

class _CustomerCreatePageState extends ConsumerState<CustomerCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _tax = TextEditingController();
  final _terms = TextEditingController();
  final _credit = TextEditingController();
  bool _saving = false;
  bool _isLoyalty = false;

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

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.createCustomer(
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        taxNumber: _tax.text.trim().isEmpty ? null : _tax.text.trim(),
        paymentTerms: int.tryParse(_terms.text.trim()),
        creditLimit: double.tryParse(_credit.text.trim()),
        isLoyalty: _isLoyalty,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Customer')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name'), validator: _req),
              const SizedBox(height: 8),
              TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 8),
              TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 8),
              TextFormField(controller: _tax, decoration: const InputDecoration(labelText: 'Tax Number')),
              const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextFormField(controller: _terms, decoration: const InputDecoration(labelText: 'Payment Terms (days)'), keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _credit, decoration: const InputDecoration(labelText: 'Credit Limit'), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Switch(value: _isLoyalty, onChanged: (v) => setState(() => _isLoyalty = v)),
            const SizedBox(width: 8),
            const Text('Enroll in loyalty')
          ]),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_rounded), label: const Text('Create Customer')),
            ],
          ),
        ),
      ),
    );
  }
}

