import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/features/accounts/data/accounts_repository.dart';
import 'package:ebs_lite/features/accounts/data/models.dart';
import 'package:ebs_lite/shared/widgets/app_empty_view.dart';
import 'package:ebs_lite/shared/widgets/app_error_view.dart';
import 'package:ebs_lite/shared/widgets/app_loading_view.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import 'asset_consumable_shared.dart';

class ConsumableCategoryManagementPage extends ConsumerStatefulWidget {
  const ConsumableCategoryManagementPage({super.key});

  @override
  ConsumerState<ConsumableCategoryManagementPage> createState() =>
      _ConsumableCategoryManagementPageState();
}

class _ConsumableCategoryManagementPageState
    extends ConsumerState<ConsumableCategoryManagementPage> {
  bool _loading = true;
  Object? _error;
  String _query = '';
  List<ConsumableCategoryDto> _items = const [];
  List<LedgerBalanceDto> _ledgers = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final inventoryRepo = ref.read(inventoryRepositoryProvider);
      final accountsRepo = ref.read(accountsRepositoryProvider);
      final results = await Future.wait([
        inventoryRepo.getConsumableCategories(),
        accountsRepo.getLedgerBalances(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<ConsumableCategoryDto>;
        _ledgers = results[1] as List<LedgerBalanceDto>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ConsumableCategoryDto> get _filteredItems {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((item) {
      return [
        item.name,
        item.description ?? '',
        item.ledgerDisplay,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _openDialog([ConsumableCategoryDto? existing]) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => _ConsumableCategoryDialog(
        existing: existing,
        ledgers: _ledgers,
      ),
    );
    if (updated == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Consumable Categories'),
        actions: [
          IconButton(
            tooltip: 'Add category',
            onPressed: () => _openDialog(),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _loading && _items.isEmpty
            ? const AppLoadingView(label: 'Loading consumable categories')
            : _error != null && _items.isEmpty
                ? AppErrorView(error: _error!, onRetry: _load)
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search category or ledger',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                      Expanded(
                        child: _filteredItems.isEmpty
                            ? const AppEmptyView(
                                title: 'No consumable categories found',
                                message:
                                    'Create categories to standardize expense routing for consumable usage.',
                                icon: Icons.category_outlined,
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = _filteredItems[index];
                                  return Card(
                                    elevation: 0,
                                    child: ListTile(
                                      leading:
                                          const Icon(Icons.category_rounded),
                                      title: Text(item.name),
                                      subtitle: Text(
                                        [
                                          item.ledgerDisplay,
                                          if ((item.description ?? '')
                                              .trim()
                                              .isNotEmpty)
                                            item.description!.trim(),
                                        ].join(' • '),
                                      ),
                                      trailing: Chip(
                                        label: Text(
                                          item.isActive ? 'Active' : 'Inactive',
                                        ),
                                      ),
                                      onTap: () => _openDialog(item),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ConsumableCategoryDialog extends ConsumerStatefulWidget {
  const _ConsumableCategoryDialog({
    required this.ledgers,
    this.existing,
  });

  final List<LedgerBalanceDto> ledgers;
  final ConsumableCategoryDto? existing;

  @override
  ConsumerState<_ConsumableCategoryDialog> createState() =>
      _ConsumableCategoryDialogState();
}

class _ConsumableCategoryDialogState
    extends ConsumerState<_ConsumableCategoryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  LedgerBalanceDto? _selectedLedger;
  bool _active = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.existing?.description ?? '');
    _selectedLedger = widget.ledgers.cast<LedgerBalanceDto?>().firstWhere(
          (item) => item?.accountId == widget.existing?.ledgerAccountId,
          orElse: () => null,
        );
    _active = widget.existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Enter a category name.');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      if (_isEdit) {
        await repo.updateConsumableCategory(
          id: widget.existing!.categoryId,
          name: _nameController.text.trim(),
          description: _descriptionController.text,
          ledgerAccountId: _selectedLedger?.accountId,
          isActive: _active,
        );
      } else {
        await repo.createConsumableCategory(
          name: _nameController.text.trim(),
          description: _descriptionController.text,
          ledgerAccountId: _selectedLedger?.accountId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage(ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .deleteConsumableCategory(existing.categoryId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage(ErrorHandler.message(e));
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          _isEdit ? 'Edit Consumable Category' : 'New Consumable Category'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _saving
                    ? null
                    : () async {
                        final picked =
                            await showSearchPickerDialog<LedgerBalanceDto>(
                          context: context,
                          title: 'Select Consumable Expense Ledger',
                          items: widget.ledgers,
                          titleBuilder: (item) => [
                            item.accountCode ?? '',
                            item.accountName ?? 'Ledger #${item.accountId}',
                          ].where((value) => value.trim().isNotEmpty).join(' '),
                          subtitleBuilder: (item) => item.accountType ?? '',
                          searchTextBuilder: (item) => [
                            item.accountId.toString(),
                            item.accountCode ?? '',
                            item.accountName ?? '',
                            item.accountType ?? '',
                          ].join(' '),
                        );
                        if (picked != null) {
                          setState(() => _selectedLedger = picked);
                        }
                      },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expense Ledger',
                    prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedLedger == null
                              ? 'Use default consumables expense ledger'
                              : [
                                  _selectedLedger!.accountCode ?? '',
                                  _selectedLedger!.accountName ?? '',
                                ]
                                  .where((value) => value.trim().isNotEmpty)
                                  .join(' '),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded),
                    ],
                  ),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _active,
                  title: const Text('Active'),
                  contentPadding: EdgeInsets.zero,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _active = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_isEdit)
          TextButton(
            onPressed: _saving ? null : _delete,
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
