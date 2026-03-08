import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/accounts_repository.dart';
import '../../data/models.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../../../shared/widgets/app_error_view.dart';

class AuditLogsPage extends ConsumerStatefulWidget {
  const AuditLogsPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends ConsumerState<AuditLogsPage> {
  bool _loading = true;
  Object? _error;
  List<AuditLogDto> _logs = const [];

  final TextEditingController _action = TextEditingController();
  final TextEditingController _userId = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _action.dispose();
    _userId.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final uid = int.tryParse(_userId.text.trim());
      final list = await repo.getAuditLogs(
        userId: uid,
        action: _action.text.trim(),
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (!mounted) return;
      setState(() => _logs = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateRange({required bool from}) async {
    final initial = from ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
    await _load();
  }

  Future<void> _showDetails(AuditLogDto log) async {
    final encoder = const JsonEncoder.withIndent('  ');
    String? encode(dynamic v) {
      if (v == null) return null;
      if (v is String) return v;
      try {
        return encoder.convert(v);
      } catch (_) {
        return v.toString();
      }
    }

    final oldValue = encode(log.oldValue);
    final newValue = encode(log.newValue);
    final changes = encode(log.fieldChanges);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audit Log Details'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('Action', log.action),
                _detail('Table', log.tableName),
                _detail('Record ID', log.recordId?.toString() ?? '—'),
                _detail('User ID', log.userId?.toString() ?? '—'),
                _detail('IP', log.ipAddress ?? '—'),
                _detail('User Agent', log.userAgent ?? '—'),
                const SizedBox(height: 8),
                if (changes != null) _detail('Field Changes', changes),
                if (oldValue != null) _detail('Old Value', oldValue),
                if (newValue != null) _detail('New Value', newValue),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    String dateLabel(DateTime? d) =>
        d == null ? 'Any' : DateFormat('yyyy-MM-dd').format(d);

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.fromMenu,
        leading: widget.fromMenu
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: widget.fromMenu
          ? DashboardSidebar(
              onSelect: (label) => widget.onMenuSelect?.call(context, label),
            )
          : null,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? AppErrorView(error: _error!, onRetry: _load)
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _action,
                                    decoration: const InputDecoration(
                                      labelText: 'Action',
                                      prefixIcon: Icon(Icons.search_rounded),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _userId,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'User ID',
                                      prefixIcon: Icon(Icons.person_rounded),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _pickDateRange(from: true),
                                  icon: const Icon(Icons.event_rounded),
                                  label: Text('From: ${dateLabel(_fromDate)}'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _pickDateRange(from: false),
                                  icon:
                                      const Icon(Icons.event_available_rounded),
                                  label: Text('To: ${dateLabel(_toDate)}'),
                                ),
                                FilledButton(
                                  onPressed: _load,
                                  child: const Text('Apply'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _logs.isEmpty
                            ? const Center(child: Text('No audit logs found'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _logs.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final log = _logs[i];
                                  final title =
                                      '${log.action} • ${log.tableName}';
                                  final subtitle = [
                                    if (log.recordId != null)
                                      'Record: ${log.recordId}',
                                    if (log.userId != null)
                                      'User: ${log.userId}',
                                    df.format(log.timestamp.toLocal()),
                                  ].join(' • ');
                                  return Card(
                                    elevation: 0,
                                    child: ListTile(
                                      leading:
                                          const Icon(Icons.fact_check_rounded),
                                      title: Text(title),
                                      subtitle: Text(subtitle),
                                      trailing: const Icon(
                                          Icons.chevron_right_rounded),
                                      onTap: () => _showDetails(log),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}
