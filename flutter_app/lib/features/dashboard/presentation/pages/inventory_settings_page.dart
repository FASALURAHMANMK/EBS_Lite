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
  String _negativeProfitPolicy = 'DONT_ALLOW';
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
        _negativeProfitPolicy = settings.negativeProfitPolicy;
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
    final requiresApprovalPassword =
        _negativeStockPolicy == 'ALLOW_WITH_APPROVAL' ||
            _negativeProfitPolicy == 'ALLOW_WITH_APPROVAL';
    if (requiresApprovalPassword) {
      if (!_hasApprovalPassword && password.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Set an approval password before enabling approval'),
          ));
        return;
      }
      if (password.isNotEmpty || confirmPassword.isNotEmpty) {
        if (password.length < 4) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content:
                  Text('Use at least 4 characters for the approval password'),
            ));
          return;
        }
        if (password != confirmPassword) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content:
                    Text('Approval password and confirmation do not match'),
              ),
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
              negativeProfitPolicy: _negativeProfitPolicy,
              negativeStockApprovalPassword: password.isEmpty ? null : password,
            ),
          );
      if (!mounted) return;
      _password.clear();
      _confirmPassword.clear();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Inventory configuration submitted for approval. Live settings remain unchanged until approved.',
            ),
          ),
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
    final costingLabel = _costingMethod == 'WAC'
        ? 'Weighted Average Cost (WAC)'
        : 'First In, First Out (FIFO)';
    final policyHelpText = switch (_negativeStockPolicy) {
      'ALLOW' =>
        'Stock-out actions can continue even if the selected variation goes below zero.',
      'ALLOW_WITH_APPROVAL' =>
        'A password is required whenever a stock-out action would make the selected variation go below zero.',
      _ =>
        'Stock-out actions stop when the selected variation would go below zero.',
    };
    final profitHelpText = switch (_negativeProfitPolicy) {
      'ALLOW' =>
        'Sales can complete even when the transaction finishes below tracked cost.',
      'ALLOW_WITH_APPROVAL' =>
        'An approval password is required when a sale would finish in a loss.',
      _ => 'Sales that would finish in a loss are blocked.',
    };
    final requiresApprovalPassword =
        _negativeStockPolicy == 'ALLOW_WITH_APPROVAL' ||
            _negativeProfitPolicy == 'ALLOW_WITH_APPROVAL';
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
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_rounded),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Inventory costing method',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              Text(
                                'Locked',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            costingLabel,
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'This is chosen when the company is created and cannot be changed later.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Negative stock control',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'When stock would go below zero',
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
                            child: Text('Block negative stock'),
                          ),
                          DropdownMenuItem(
                            value: 'ALLOW',
                            child: Text('Allow negative stock'),
                          ),
                          DropdownMenuItem(
                            value: 'ALLOW_WITH_APPROVAL',
                            child: Text('Allow with password approval'),
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
                    policyHelpText,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Applied to variation-level stock reductions in POS, stock adjustments, transfer dispatch, sales, and purchase returns.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Negative profit control',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'When a sale would finish in a loss',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.trending_down_rounded),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _negativeProfitPolicy,
                        items: const [
                          DropdownMenuItem(
                            value: 'DONT_ALLOW',
                            child: Text('Block negative profit'),
                          ),
                          DropdownMenuItem(
                            value: 'ALLOW',
                            child: Text('Allow negative profit'),
                          ),
                          DropdownMenuItem(
                            value: 'ALLOW_WITH_APPROVAL',
                            child: Text('Allow with password approval'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _negativeProfitPolicy = value);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profitHelpText,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Applied to completed sales, resumed held sales, POS checkout, and quote-to-sale conversion.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (requiresApprovalPassword) ...[
                    const SizedBox(height: 16),
                    if (_hasApprovalPassword)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'An approval password is already set. Leave these fields blank to keep it unchanged. The same password is used for stock and negative-profit approvals.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Shared approval password',
                        hintText: 'Enter a new password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm shared approval password',
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
                          : const Text('Save Inventory Configuration'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
