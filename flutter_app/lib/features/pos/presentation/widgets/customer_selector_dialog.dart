import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../data/models.dart';
import '../../data/pos_repository.dart';

class CustomerSelectorDialog extends ConsumerStatefulWidget {
  const CustomerSelectorDialog({super.key});

  @override
  ConsumerState<CustomerSelectorDialog> createState() =>
      _CustomerSelectorDialogState();
}

class _CustomerSelectorDialogState
    extends ConsumerState<CustomerSelectorDialog> {
  final _controller = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _adding = false;
  List<PosCustomerDto> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _search(''));
  }

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
        _error = ErrorHandler.message(e);
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
      final c = await repo.quickAddCustomer(
          name: name,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(c);
    } catch (e) {
      setState(() => _adding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
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
    return AppSelectionDialog(
      title: 'Select Customer',
      maxWidth: 460,
      maxHeight: 580,
      loading: _loading,
      errorText: _error,
      searchField: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Search name / phone / email',
          prefixIcon: Icon(Icons.search_rounded),
        ),
        onChanged: (value) => _search(value.trim()),
      ),
      body: Column(
        children: [
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(child: Text('No customers'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final c = _results[index];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text(
                            [c.phone, c.email].whereType<String>().join(' • ')),
                        onTap: () => Navigator.of(context).pop(c),
                      );
                    },
                  ),
          ),
          const Divider(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Quick Add',
              style: Theme.of(context).textTheme.titleSmall,
            ),
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
          const SizedBox(height: 12),
        ],
      ),
      
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _adding ? null : _quickAdd,
          icon: _adding
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
      ],
    );
  }
}
