import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';

class PeriodClosePage extends ConsumerStatefulWidget {
  const PeriodClosePage({super.key});

  @override
  ConsumerState<PeriodClosePage> createState() => _PeriodClosePageState();
}

class _PeriodClosePageState extends ConsumerState<PeriodClosePage> {
  bool _loading = true;
  Object? _error;
  List<AccountingPeriodDto> _periods = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items =
          await ref.read(accountsRepositoryProvider).getAccountingPeriods();
      if (!mounted) return;
      setState(() => _periods = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final localePrefs = ref.read(localePreferencesProvider);
    var startDate = DateTime.now();
    var endDate = DateTime.now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Create Accounting Period'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Period Name'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: Text(
                    AppDateTime.formatDate(context, localePrefs, startDate),
                  ),
                  subtitle: const Text('Start date'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setStateDialog(() {
                        startDate = picked;
                        if (endDate.isBefore(startDate)) {
                          endDate = startDate;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_rounded),
                  title: Text(
                    AppDateTime.formatDate(context, localePrefs, endDate),
                  ),
                  subtitle: const Text('End date'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setStateDialog(() => endDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await ref.read(accountsRepositoryProvider).createAccountingPeriod(
            periodName: nameCtrl.text,
            startDate: startDate,
            endDate: endDate,
            notes: notesCtrl.text,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _changeStatus(AccountingPeriodDto item, bool close) async {
    try {
      final repo = ref.read(accountsRepositoryProvider);
      if (close) {
        await repo.closeAccountingPeriod(periodId: item.periodId);
      } else {
        await repo.reopenAccountingPeriod(periodId: item.periodId);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Period Close'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateDialog,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: _loading
            ? const AppLoadingView(label: 'Loading periods')
            : _error != null
                ? AppErrorView(error: _error!, onRetry: _load)
                : _periods.isEmpty
                    ? const AppEmptyView(
                        title: 'No accounting periods found',
                        message:
                            'Create accounting periods to monitor close readiness and checklist status.',
                        icon: Icons.event_note_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _periods.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _periods[index];
                          final checklistItems =
                              item.checklist.entries.toList();
                          return Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.periodName} • ${AppDateTime.formatDate(context, localePrefs, item.startDate)} to ${AppDateTime.formatDate(context, localePrefs, item.endDate)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () => _changeStatus(
                                          item,
                                          item.status != 'CLOSED',
                                        ),
                                        child: Text(
                                          item.status == 'CLOSED'
                                              ? 'Reopen'
                                              : 'Close',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    [
                                      'Status ${item.status}',
                                      if (item.closedAt != null)
                                        'Closed ${AppDateTime.formatDateTime(context, localePrefs, item.closedAt)}',
                                      if ((item.notes ?? '').isNotEmpty)
                                        item.notes!,
                                    ].join(' • '),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: checklistItems.map((entry) {
                                      final value = entry.value;
                                      final passed = value is Map &&
                                          (value['passed'] as bool? ?? false);
                                      return Chip(
                                        label: Text(
                                          '${entry.key.replaceAll('_', ' ')}: ${passed ? 'OK' : 'Attention'}',
                                        ),
                                        backgroundColor: passed
                                            ? Colors.green
                                                .withValues(alpha: 0.12)
                                            : Colors.orange
                                                .withValues(alpha: 0.12),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
