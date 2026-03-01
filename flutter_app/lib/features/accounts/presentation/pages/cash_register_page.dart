import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../dashboard/controllers/location_notifier.dart';
import '../../../dashboard/data/models.dart';
import '../../../accounts/data/accounts_repository.dart';
import '../../../accounts/data/models.dart';
import '../../../../core/error_handler.dart';

class CashRegisterPage extends ConsumerStatefulWidget {
  const CashRegisterPage({super.key});

  @override
  ConsumerState<CashRegisterPage> createState() => _CashRegisterPageState();
}

class _CashRegisterPageState extends ConsumerState<CashRegisterPage> {
  bool _loading = true;
  bool _actionBusy = false;
  String? _error;
  int? _lastLocationId;
  List<CashRegisterDto> _registers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loc = ref.read(locationNotifierProvider).selected;
    if (loc == null) {
      setState(() {
        _loading = false;
        _error = 'Select a location to view cash registers.';
        _registers = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final list = await repo.getCashRegisters(locationId: loc.locationId);
      if (!mounted) return;
      setState(() {
        _registers = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.message(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncLocation(Location? location) {
    final id = location?.locationId;
    if (id == null || id == _lastLocationId) return;
    _lastLocationId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  CashRegisterDto? get _openRegister {
    for (final r in _registers) {
      if (r.status.toUpperCase() == 'OPEN') return r;
    }
    return null;
  }

  Future<void> _openRegisterDialog(Location location) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Cash Register'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Opening Balance',
            prefixIcon: Icon(Icons.account_balance_wallet_rounded),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final raw = controller.text.trim();
                final val = double.tryParse(raw);
                Navigator.of(context).pop(val);
              },
              child: const Text('Open')),
        ],
      ),
    );
    if (value == null) return;
    setState(() => _actionBusy = true);
    try {
      await ref.read(accountsRepositoryProvider).openCashRegister(
            openingBalance: value,
            locationId: location.locationId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash register opened')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _closeRegisterDialog(Location location) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Cash Register'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Closing Balance',
            prefixIcon: Icon(Icons.lock_rounded),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final raw = controller.text.trim();
                final val = double.tryParse(raw);
                Navigator.of(context).pop(val);
              },
              child: const Text('Close')),
        ],
      ),
    );
    if (value == null) return;
    setState(() => _actionBusy = true);
    try {
      await ref.read(accountsRepositoryProvider).closeCashRegister(
            closingBalance: value,
            locationId: location.locationId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash register closed')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _tallyDialog(Location location) async {
    final countController = TextEditingController();
    final notesController = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Cash Tally'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Count',
                prefixIcon: Icon(Icons.calculate_rounded),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final raw = countController.text.trim();
                final val = double.tryParse(raw);
                Navigator.of(context).pop(val);
              },
              child: const Text('Save')),
        ],
      ),
    );
    if (value == null) return;
    setState(() => _actionBusy = true);
    try {
      await ref.read(accountsRepositoryProvider).recordCashTally(
            count: value,
            notes: notesController.text.trim(),
            locationId: location.locationId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash tally recorded')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationNotifierProvider);
    final location = locationState.selected;
    _syncLocation(location);

    final theme = Theme.of(context);
    final openRegister = _openRegister;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Register'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _LocationHeader(location: location),
                      const SizedBox(height: 12),
                      _RegisterSummary(
                        register: openRegister,
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _actionBusy || location == null
                                  ? null
                                  : () => _openRegisterDialog(location),
                              icon: const Icon(Icons.lock_open_rounded),
                              label: const Text('Open'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _actionBusy || location == null
                                  ? null
                                  : () => _closeRegisterDialog(location),
                              icon: const Icon(Icons.lock_rounded),
                              label: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _actionBusy || location == null
                            ? null
                            : () => _tallyDialog(location),
                        icon: const Icon(Icons.calculate_rounded),
                        label: const Text('Record Tally'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Register History',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_registers.isEmpty)
                        const Center(child: Text('No cash registers found'))
                      else
                        ..._registers.map((r) => _RegisterCard(register: r)),
                    ],
                  ),
      ),
    );
  }
}

class _LocationHeader extends StatelessWidget {
  const _LocationHeader({required this.location});

  final Location? location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = location == null
        ? 'No location selected'
        : 'Location: ${location!.name}';
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.storefront_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterSummary extends StatelessWidget {
  const _RegisterSummary({required this.register, required this.theme});

  final CashRegisterDto? register;
  final ThemeData theme;

  String _fmt(double value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (register == null) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('No open cash register.'),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded),
                const SizedBox(width: 8),
                Text(
                  'Open Register',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                Chip(
                  label: Text(register!.status),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _metric('Opening', _fmt(register!.openingBalance)),
                _metric('Expected', _fmt(register!.expectedBalance)),
                _metric('Cash In', _fmt(register!.cashIn)),
                _metric('Cash Out', _fmt(register!.cashOut)),
                _metric('Variance', _fmt(register!.variance)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _RegisterCard extends StatelessWidget {
  const _RegisterCard({required this.register});

  final CashRegisterDto register;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final title = 'Register #${register.registerId}';
    final subtitle = [
      'Date: ${df.format(register.date.toLocal())}',
      'Status: ${register.status}',
    ].join(' • ');
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.receipt_long_rounded),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Open: ${register.openingBalance.toStringAsFixed(2)}'),
            Text('Close: ${(register.closingBalance ?? 0).toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }
}
