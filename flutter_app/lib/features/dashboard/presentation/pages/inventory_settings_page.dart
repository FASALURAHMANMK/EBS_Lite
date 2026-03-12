import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../data/settings_models.dart';
import '../../data/settings_repository.dart';

class InventorySettingsPage extends ConsumerStatefulWidget {
  const InventorySettingsPage({super.key});

  @override
  ConsumerState<InventorySettingsPage> createState() =>
      _InventorySettingsPageState();
}

class _InventorySettingsPageState extends ConsumerState<InventorySettingsPage> {
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _costingMethod = 'FIFO';
  String _negativeStockPolicy = 'DONT_ALLOW';
  bool _hasApprovalPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings =
          await ref.read(settingsRepositoryProvider).getInventorySettings();
      if (!mounted) return;
      setState(() {
        _costingMethod = settings.inventoryCostingMethod;
        _negativeStockPolicy = settings.negativeStockPolicy;
        _hasApprovalPassword = settings.hasNegativeStockApprovalPassword;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final password = _password.text.trim();
    final confirmPassword = _confirmPassword.text.trim();
    if (_negativeStockPolicy == 'ALLOW_WITH_APPROVAL') {
      if (!_hasApprovalPassword && password.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Set an approval password to enable this policy'),
          ));
        return;
      }
      if (password.isNotEmpty || confirmPassword.isNotEmpty) {
        if (password.length < 4) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text('Approval password must be at least 4 characters'),
            ));
          return;
        }
        if (password != confirmPassword) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Passwords do not match')),
            );
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      await ref.read(settingsRepositoryProvider).updateInventorySettings(
            UpdateInventorySettingsDto(
              negativeStockPolicy: _negativeStockPolicy,
              negativeStockApprovalPassword: password.isEmpty ? null : password,
            ),
          );
      if (!mounted) return;
      _password.clear();
      _confirmPassword.clear();
      setState(() =>
          _hasApprovalPassword = _negativeStockPolicy == 'ALLOW_WITH_APPROVAL');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Inventory settings updated')),
        );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Configuration')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 0,
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2_rounded),
                      title: const Text('Inventory costing method'),
                      subtitle: Text(
                        _costingMethod == 'WAC'
                            ? 'Weighted Average Cost'
                            : 'FIFO',
                      ),
                      trailing: Text(
                        'Set during company creation',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Negative stock policy',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warning_amber_rounded),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _negativeStockPolicy,
                        items: const [
                          DropdownMenuItem(
                            value: 'DONT_ALLOW',
                            child: Text('Do not allow'),
                          ),
                          DropdownMenuItem(
                            value: 'ALLOW',
                            child: Text('Allow'),
                          ),
                          DropdownMenuItem(
                            value: 'ALLOW_WITH_APPROVAL',
                            child: Text('Allow with approval password'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _negativeStockPolicy = value);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This rule is enforced on variation-level stock reductions across POS, stock adjustments, transfer dispatch, and purchase returns.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (_negativeStockPolicy == 'ALLOW_WITH_APPROVAL') ...[
                    const SizedBox(height: 16),
                    if (_hasApprovalPassword)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'An approval password is already configured. Leave the fields below empty to keep it unchanged.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Approval password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
