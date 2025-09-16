import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../loyalty/data/loyalty_repository.dart';

class LoyaltyManagementPage extends ConsumerStatefulWidget {
  const LoyaltyManagementPage({super.key});
  @override
  ConsumerState<LoyaltyManagementPage> createState() =>
      _LoyaltyManagementPageState();
}

class _LoyaltyManagementPageState extends ConsumerState<LoyaltyManagementPage> {
  late Future<LoyaltySettingsDto> _settingsFuture;
  late Future<List<LoyaltyTierDto>> _tiersFuture;

  final _formKey = GlobalKey<FormState>();
  final _pointsPerCurrency = TextEditingController();
  final _pointValue = TextEditingController();
  final _minRedemption = TextEditingController();
  final _minReserve = TextEditingController();
  final _expiryDays = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(loyaltyRepositoryProvider);
    _settingsFuture = repo.getSettings();
    _tiersFuture = repo.getTiers();
  }

  Future<void> _saveSettings() async {
    // Validate inputs before sending to backend
    if (_formKey.currentState?.validate() != true) return;

    final repo = ref.read(loyaltyRepositoryProvider);
    try {
      await repo.updateSettings(
        pointsPerCurrency: double.tryParse(_pointsPerCurrency.text.trim()),
        pointValue: double.tryParse(_pointValue.text.trim()),
        minRedemptionPoints: int.tryParse(_minRedemption.text.trim()),
        minPointsReserve: int.tryParse(_minReserve.text.trim()),
        pointsExpiryDays: int.tryParse(_expiryDays.text.trim()),
      );
      setState(_reload);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings updated')));
    } catch (e) {
      // Show a friendly error including backend validation details if available
      String message = 'Failed to update settings';
      try {
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map) {
            final msg = data['message']?.toString();
            final err = data['error']?.toString();
            if (msg != null && msg.isNotEmpty) message = msg;
            if (err != null && err.isNotEmpty) message = '$message: $err';
            // If validation errors map is present under data, join them
            final validations = data['data'];
            if (validations is Map) {
              final parts = validations.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join(', ');
              if (parts.isNotEmpty) message = '$message ($parts)';
            }
          } else if (e.message != null) {
            message = e.message!;
          }
        }
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _addTierDialog() async {
    final nameCtrl = TextEditingController();
    final minPtsCtrl = TextEditingController(text: '0');
    final ppcCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Loyalty Tier'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(
              controller: minPtsCtrl,
              decoration: const InputDecoration(labelText: 'Min Points'),
              keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(
              controller: ppcCtrl,
              decoration: const InputDecoration(
                  labelText: 'Points per currency (optional)'),
              keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (ok == true) {
      final repo = ref.read(loyaltyRepositoryProvider);
      await repo.createTier(
          name: nameCtrl.text.trim(),
          minPoints: double.tryParse(minPtsCtrl.text.trim()) ?? 0,
          pointsPerCurrency: double.tryParse(ppcCtrl.text.trim()));
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Loyalty Management')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _addTierDialog, label: const Icon(Icons.add_rounded)),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<LoyaltySettingsDto>(
              future: _settingsFuture,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Column(children: [
                    Text('Failed to load settings: ${snap.error}'),
                    const SizedBox(height: 8),
                    FilledButton(
                        onPressed: () => setState(_reload),
                        child: const Text('Retry')),
                  ]);
                }
                if (!snap.hasData) {
                  return const LinearProgressIndicator(minHeight: 2);
                }
                final s = snap.data!;
                _pointsPerCurrency.text = s.pointsPerCurrency.toString();
                _pointValue.text = s.pointValue.toString();
                _minRedemption.text = s.minRedemptionPoints.toString();
                _minReserve.text = s.minPointsReserve.toString();
                _expiryDays.text = s.pointsExpiryDays.toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                        key: _formKey,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Loyalty Settings',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: _pointsPerCurrency,
                              decoration: const InputDecoration(
                                  labelText: 'Points per currency'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                final val = double.tryParse(v?.trim() ?? '');
                                if (val == null) return 'Enter a valid number';
                                if (val <= 0) return 'Must be greater than 0';
                                return null;
                              }),
                          const SizedBox(height: 8),
                          TextFormField(
                              controller: _pointValue,
                              decoration: const InputDecoration(
                                  labelText: 'Point value'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                final val = double.tryParse(v?.trim() ?? '');
                                if (val == null) return 'Enter a valid number';
                                if (val <= 0) return 'Must be greater than 0';
                                return null;
                              }),
                          const SizedBox(height: 8),
                          TextFormField(
                              controller: _minRedemption,
                              decoration: const InputDecoration(
                                  labelText: 'Min redemption points'),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final val = int.tryParse(v?.trim() ?? '');
                                if (val == null) return 'Enter a valid integer';
                                if (val <= 0) return 'Must be greater than 0';
                                return null;
                              }),
                          const SizedBox(height: 8),
                          TextFormField(
                              controller: _minReserve,
                              decoration: const InputDecoration(
                                  labelText: 'Min points reserve'),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final val = int.tryParse(v?.trim() ?? '');
                                if (val == null) return 'Enter a valid integer';
                                if (val < 0) return 'Cannot be negative';
                                return null;
                              }),
                          const SizedBox(height: 8),
                          TextFormField(
                              controller: _expiryDays,
                              decoration: const InputDecoration(
                                  labelText: 'Points expiry days'),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final val = int.tryParse(v?.trim() ?? '');
                                if (val == null) return 'Enter a valid integer';
                                if (val <= 0) return 'Must be greater than 0';
                                return null;
                              }),
                          const SizedBox(height: 12),
                          Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                  onPressed: _saveSettings,
                                  icon: const Icon(Icons.save_rounded),
                                  label: const Text('Save Settings'))),
                        ])),
                  ),
                );
              },
            ),
            Text('Loyalty Tiers',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<LoyaltyTierDto>>(
              future: _tiersFuture,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Column(children: [
                    Text('Failed to load tiers: ${snap.error}'),
                    const SizedBox(height: 8),
                    FilledButton(
                        onPressed: () => setState(_reload),
                        child: const Text('Retry')),
                  ]);
                }
                if (!snap.hasData) {
                  return const LinearProgressIndicator(minHeight: 2);
                }
                final tiers = snap.data!;
                if (tiers.isEmpty) return const Text('No tiers defined');
                return Column(
                  children: tiers
                      .map((t) => _TierTile(
                          tier: t, onUpdated: () => setState(_reload)))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TierTile extends ConsumerWidget {
  const _TierTile({required this.tier, required this.onUpdated});
  final LoyaltyTierDto tier;
  final VoidCallback onUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(tier.name),
        subtitle: Text(
            'Min points: ${tier.minPoints.toStringAsFixed(2)}${tier.pointsPerCurrency != null ? ' | Points/cur: ${tier.pointsPerCurrency}' : ''}${tier.isActive ? '' : ' | Inactive'}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final nameCtrl = TextEditingController(text: tier.name);
              final minPtsCtrl =
                  TextEditingController(text: tier.minPoints.toString());
              final ppcCtrl = TextEditingController(
                  text: tier.pointsPerCurrency?.toString() ?? '');
              bool active = tier.isActive;
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => StatefulBuilder(builder: (context, setSt) {
                  return AlertDialog(
                    title: const Text('Edit Tier'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: nameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Tier name')),
                      const SizedBox(height: 8),
                      TextField(
                          controller: minPtsCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Min points'),
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      TextField(
                          controller: ppcCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Points per currency (optional)'),
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Text('Active'),
                        Switch(
                            value: active,
                            onChanged: (v) => setSt(() => active = v))
                      ])
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save')),
                    ],
                  );
                }),
              );
              if (ok == true) {
                final repo = ref.read(loyaltyRepositoryProvider);
                await repo.updateTier(
                  tierId: tier.tierId,
                  name: nameCtrl.text.trim(),
                  minPoints: double.tryParse(minPtsCtrl.text.trim()),
                  pointsPerCurrency: double.tryParse(ppcCtrl.text.trim()),
                  isActive: active,
                );
                onUpdated();
              }
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_forever_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                          title: const Text('Delete Tier?'),
                          content: const Text('This action cannot be undone.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'))
                          ]));
              if (ok == true) {
                final repo = ref.read(loyaltyRepositoryProvider);
                await repo.deleteTier(tier.tierId);
                onUpdated();
              }
            },
          ),
        ]),
      ),
    );
  }
}
