import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/hr_repository.dart';
import '../../data/models.dart';
import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_error_view.dart';

class LeaveApprovalsPage extends ConsumerStatefulWidget {
  const LeaveApprovalsPage({super.key});

  @override
  ConsumerState<LeaveApprovalsPage> createState() => _LeaveApprovalsPageState();
}

class _LeaveApprovalsPageState extends ConsumerState<LeaveApprovalsPage> {
  bool _loading = true;
  Object? _error;
  List<LeaveApprovalDto> _leaves = const [];

  String _status = 'PENDING'; // PENDING | APPROVED | REJECTED | ALL

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
      final list = await ref.read(hrRepositoryProvider).getLeaves(
            status: _status == 'ALL' ? null : _status,
          );
      if (!mounted) return;
      setState(() => _leaves = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _promptNotes({required String title}) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Decision notes (optional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
  }

  Future<void> _approve(LeaveApprovalDto l) async {
    final notes = await _promptNotes(title: 'Approve leave?');
    if (!mounted) return;
    try {
      await ref
          .read(hrRepositoryProvider)
          .approveLeave(l.leaveId, decisionNotes: notes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave approved')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _reject(LeaveApprovalDto l) async {
    final notes = await _promptNotes(title: 'Reject leave?');
    if (!mounted) return;
    try {
      await ref
          .read(hrRepositoryProvider)
          .rejectLeave(l.leaveId, decisionNotes: notes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave rejected')),
      );
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
    final df = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Approvals'),
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
                ? AppErrorView(error: _error!, onRetry: _load)
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_list_rounded),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _status,
                              items: const [
                                DropdownMenuItem(
                                  value: 'PENDING',
                                  child: Text('Pending'),
                                ),
                                DropdownMenuItem(
                                  value: 'APPROVED',
                                  child: Text('Approved'),
                                ),
                                DropdownMenuItem(
                                  value: 'REJECTED',
                                  child: Text('Rejected'),
                                ),
                                DropdownMenuItem(
                                  value: 'ALL',
                                  child: Text('All'),
                                ),
                              ],
                              onChanged: (v) async {
                                setState(() => _status = v ?? 'PENDING');
                                await _load();
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _leaves.isEmpty
                            ? const Center(child: Text('No leave requests'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _leaves.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final l = _leaves[i];
                                  final subtitle = <String>[
                                    '${df.format(l.startDate)} → ${df.format(l.endDate)}',
                                    'Status: ${l.status}',
                                    if ((l.reason).trim().isNotEmpty)
                                      'Reason: ${l.reason}',
                                    if (l.approvedAt != null)
                                      'Decided: ${df.format(l.approvedAt!)}',
                                  ].join('\n');

                                  final isPending =
                                      l.status.toUpperCase() == 'PENDING';

                                  return Card(
                                    elevation: 0,
                                    child: ListTile(
                                      leading: const Icon(Icons.event_rounded),
                                      title: Text(
                                        '${l.employeeName} • #${l.employeeId}',
                                      ),
                                      subtitle: Text(subtitle),
                                      isThreeLine: true,
                                      trailing: isPending
                                          ? Wrap(
                                              spacing: 8,
                                              children: [
                                                OutlinedButton(
                                                  onPressed: () => _reject(l),
                                                  child: const Text('Reject'),
                                                ),
                                                FilledButton(
                                                  onPressed: () => _approve(l),
                                                  child: const Text('Approve'),
                                                ),
                                              ],
                                            )
                                          : null,
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
