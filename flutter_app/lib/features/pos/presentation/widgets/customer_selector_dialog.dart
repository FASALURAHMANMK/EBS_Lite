import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/pos_repository.dart';

class CustomerSelectorDialog extends ConsumerStatefulWidget {
  const CustomerSelectorDialog({super.key});

  @override
  ConsumerState<CustomerSelectorDialog> createState() => _CustomerSelectorDialogState();
}

class _CustomerSelectorDialogState extends ConsumerState<CustomerSelectorDialog> {
  final _controller = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _adding = false;
  List<PosCustomerDto> _results = const [];
  bool _loading = false;
  String? _error;

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(posRepositoryProvider);
      final list = await repo.searchCustomers(q);
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _quickAdd() async {
    final name = _nameController.text.trim();
    if (name.length < 2) return;
    setState(() => _adding = true);
    try {
      final repo = ref.read(posRepositoryProvider);
      final c = await repo.quickAddCustomer(name: name, phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(c);
    } catch (e) {
      setState(() => _adding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Customer'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search name / phone / email',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) {
                if (v.trim().isEmpty) {
                  setState(() => _results = const []);
                } else {
                  _search(v);
                }
              },
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final c = _results[index];
                  return ListTile(
                    title: Text(c.name),
                    subtitle: Text([c.phone, c.email].whereType<String>().join(' • ')),
                    onTap: () => Navigator.of(context).pop(c),
                  );
                },
              ),
            ),
            const Divider(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Quick Add', style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_add_alt_1_rounded),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: Icon(Icons.phone_rounded),
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
        FilledButton.icon(
          onPressed: _adding ? null : _quickAdd,
          icon: _adding ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

