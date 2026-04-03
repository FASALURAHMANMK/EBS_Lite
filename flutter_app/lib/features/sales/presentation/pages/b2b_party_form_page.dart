import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../customers/data/customer_repository.dart';

class B2BPartyFormPage extends ConsumerStatefulWidget {
  const B2BPartyFormPage({super.key, this.customerId});

  final int? customerId;

  bool get isEdit => customerId != null;

  @override
  ConsumerState<B2BPartyFormPage> createState() => _B2BPartyFormPageState();
}

class _B2BPartyFormPageState extends ConsumerState<B2BPartyFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _contactPerson = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _shippingAddress = TextEditingController();
  final _tax = TextEditingController();
  final _terms = TextEditingController();
  final _credit = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _load();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _contactPerson.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _shippingAddress.dispose();
    _tax.dispose();
    _terms.dispose();
    _credit.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final customer = await ref
          .read(customerRepositoryProvider)
          .getCustomer(widget.customerId!);
      if (!mounted) return;
      setState(() {
        _name.text = customer.name;
        _contactPerson.text = customer.contactPerson ?? '';
        _phone.text = customer.phone ?? '';
        _email.text = customer.email ?? '';
        _address.text = customer.address ?? '';
        _shippingAddress.text = customer.shippingAddress ?? '';
        _tax.text = customer.taxNumber ?? '';
        _terms.text = customer.paymentTerms.toString();
        _credit.text = customer.creditLimit.toStringAsFixed(2);
        _active = customer.isActive;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      if (widget.isEdit) {
        await repo.updateCustomer(
          customerId: widget.customerId!,
          name: _name.text.trim(),
          customerType: 'B2B',
          contactPerson: _contactPerson.text.trim().isEmpty
              ? null
              : _contactPerson.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          shippingAddress: _shippingAddress.text.trim().isEmpty
              ? null
              : _shippingAddress.text.trim(),
          taxNumber: _tax.text.trim().isEmpty ? null : _tax.text.trim(),
          paymentTerms: int.tryParse(_terms.text.trim()),
          creditLimit: double.tryParse(_credit.text.trim()),
          isActive: _active,
        );
      } else {
        await repo.createCustomer(
          name: _name.text.trim(),
          customerType: 'B2B',
          contactPerson: _contactPerson.text.trim().isEmpty
              ? null
              : _contactPerson.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          shippingAddress: _shippingAddress.text.trim().isEmpty
              ? null
              : _shippingAddress.text.trim(),
          taxNumber: _tax.text.trim().isEmpty ? null : _tax.text.trim(),
          paymentTerms: int.tryParse(_terms.text.trim()),
          creditLimit: double.tryParse(_credit.text.trim()),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit B2B Party' : 'New B2B Party'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration:
                          const InputDecoration(labelText: 'Party Name'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactPerson,
                      decoration:
                          const InputDecoration(labelText: 'Contact Person'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Billing Address'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _shippingAddress,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Shipping Address'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tax,
                      decoration:
                          const InputDecoration(labelText: 'Tax Registration'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _terms,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Payment Terms (days)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _credit,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Credit Limit',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.isEdit) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _active,
                        onChanged: (value) => setState(() => _active = value),
                        title: const Text('Active'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Saving...' : 'Save B2B Party'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
