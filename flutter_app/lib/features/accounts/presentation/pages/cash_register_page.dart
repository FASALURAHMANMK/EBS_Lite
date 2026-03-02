import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../dashboard/controllers/location_notifier.dart';
import '../../../dashboard/data/models.dart';
import '../../../accounts/data/accounts_repository.dart';
import '../../../accounts/data/models.dart';
import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/manager_override_dialog.dart';
import '../../controllers/training_mode_notifier.dart';
import 'day_end_flow_page.dart';

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

  Future<void> _movementDialog(
    Location location, {
    required String title,
    required String direction,
    required String reasonCode,
  }) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
            ),
            const SizedBox(height: 12),
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
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (res != true) return;
    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    if (!mounted) return;
    final approved = await showManagerOverrideDialog(
      context,
      ref,
      title: 'Manager override required',
      requiredPermissions: const ['CASH_REGISTER_MOVEMENT'],
    );
    if (approved == null) return;

    setState(() => _actionBusy = true);
    try {
      await ref.read(accountsRepositoryProvider).recordCashMovement(
            direction: direction,
            amount: amount,
            reasonCode: reasonCode,
            notes: notesController.text,
            locationId: location.locationId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title recorded')),
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

  Future<void> _forceCloseDialog(Location location) async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Force close session'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            prefixIcon: Icon(Icons.warning_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Force close'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) return;

    if (!mounted) return;
    final approved = await showManagerOverrideDialog(
      context,
      ref,
      title: 'Admin override required',
      requiredPermissions: const ['FORCE_CLOSE_CASH_REGISTER'],
    );
    if (approved == null) return;

    setState(() => _actionBusy = true);
    try {
      await ref.read(accountsRepositoryProvider).forceCloseCashRegister(
            reason: reason,
            locationId: location.locationId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash register force-closed')),
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

  Future<void> _setTrainingMode(Location location,
      {required bool enabled}) async {
    if (_actionBusy) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(enabled ? 'Enable training mode?' : 'Disable training mode?'),
        content: Text(
          enabled
              ? 'Training sales will not post to real stock/cash totals. Offline sync for checkout is disabled in training mode.'
              : 'This returns the register to normal posting mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(enabled ? 'Enable' : 'Disable'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final override = await showManagerOverrideDialog(
      context,
      ref,
      title: enabled
          ? 'Manager override: enable training'
          : 'Manager override: disable training',
      requiredPermissions: const ['TOGGLE_TRAINING_MODE'],
    );
    if (override == null) return;

    setState(() => _actionBusy = true);
    try {
      final repo = ref.read(accountsRepositoryProvider);
      if (enabled) {
        await repo.enableTrainingMode(locationId: location.locationId);
      } else {
        await repo.disableTrainingMode(locationId: location.locationId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              enabled ? 'Training mode enabled' : 'Training mode disabled'),
        ),
      );
      await _load();
      await ref.read(trainingModeNotifierProvider.notifier).refresh();
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
                      if (openRegister != null) ...[
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          child: SwitchListTile.adaptive(
                            value: openRegister.trainingMode,
                            onChanged: _actionBusy || location == null
                                ? null
                                : (v) => _setTrainingMode(location, enabled: v),
                            title: const Text('Training mode'),
                            subtitle: Text(
                              openRegister.trainingMode
                                  ? 'ON — no posting to stock/cash; banner will remain visible'
                                  : 'OFF — normal posting mode',
                            ),
                            secondary: const Icon(Icons.school_rounded),
                          ),
                        ),
                      ],
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
                              onPressed: _actionBusy ||
                                      location == null ||
                                      openRegister == null
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
                        onPressed: _actionBusy ||
                                location == null ||
                                openRegister == null
                            ? null
                            : () => _tallyDialog(location),
                        icon: const Icon(Icons.calculate_rounded),
                        label: const Text('Record Tally'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _actionBusy ||
                                      location == null ||
                                      openRegister == null
                                  ? null
                                  : () => _movementDialog(
                                        location,
                                        title: 'Cash drop',
                                        direction: 'OUT',
                                        reasonCode: 'DROP',
                                      ),
                              icon: const Icon(Icons.south_west_rounded),
                              label: const Text('Cash Drop'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _actionBusy ||
                                      location == null ||
                                      openRegister == null
                                  ? null
                                  : () => _movementDialog(
                                        location,
                                        title: 'Cash payout',
                                        direction: 'OUT',
                                        reasonCode: 'PAYOUT',
                                      ),
                              icon: const Icon(Icons.money_off_rounded),
                              label: const Text('Payout'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _actionBusy ||
                                      location == null ||
                                      openRegister == null
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const DayEndFlowPage(),
                                        ),
                                      ),
                              icon: const Icon(Icons.fact_check_rounded),
                              label: const Text('Day End'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _actionBusy ||
                                      location == null ||
                                      openRegister == null
                                  ? null
                                  : () => _forceCloseDialog(location),
                              icon: const Icon(Icons.warning_amber_rounded),
                              label: const Text('Force Close'),
                            ),
                          ),
                        ],
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
