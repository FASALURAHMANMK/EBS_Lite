import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../data/supplier_repository.dart';

class SupplierCreatePage extends ConsumerStatefulWidget {
  const SupplierCreatePage({super.key});
  @override
  ConsumerState<SupplierCreatePage> createState() => _SupplierCreatePageState();
}

class _SupplierCreatePageState extends ConsumerState<SupplierCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _terms = TextEditingController();
  final _credit = TextEditingController();
  bool _isMercantile = true;
  bool _isNonMercantile = false;
  bool _saving = false;

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

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  bool get _hasSupplierUsage => _isMercantile || _isNonMercantile;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_hasSupplierUsage) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Select at least one supplier usage type.'),
          ),
        );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(supplierRepositoryProvider);
      await repo.createSupplier(
        name: _name.text.trim(),
        contact: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        paymentTerms: int.tryParse(_terms.text.trim()),
        creditLimit: double.tryParse(_credit.text.trim()),
        isMercantile: _isMercantile,
        isNonMercantile: _isNonMercantile,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('New Supplier')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: _req),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _contact,
                  decoration:
                      const InputDecoration(labelText: 'Contact Person')),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: _terms,
                        decoration: const InputDecoration(
                            labelText: 'Payment Terms (days)'),
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                    child: TextFormField(
                        controller: _credit,
                        decoration:
                            const InputDecoration(labelText: 'Credit Limit'),
                        keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              Text(
                'Supplier Usage',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              CheckboxListTile(
                value: _isMercantile,
                contentPadding: EdgeInsets.zero,
                title: const Text('Mercantile'),
                subtitle: const Text(
                    'Buys products for resale and trading activity.'),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isMercantile = value ?? false),
              ),
              CheckboxListTile(
                value: _isNonMercantile,
                contentPadding: EdgeInsets.zero,
                title: const Text('Non-Mercantile'),
                subtitle: const Text(
                    'Buys for internal use, assets, maintenance, or consumption.'),
                onChanged: _saving
                    ? null
                    : (value) =>
                        setState(() => _isNonMercantile = value ?? false),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Create Supplier')),
            ],
          ),
        ),
      ),
    );
  }
}
