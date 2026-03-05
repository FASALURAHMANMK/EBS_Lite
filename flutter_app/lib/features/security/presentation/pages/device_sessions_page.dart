import 'package:ebs_lite/core/secure_storage.dart';
import 'package:ebs_lite/core/error_handler.dart';
import 'package:ebs_lite/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/device_sessions_repository.dart';

class DeviceSessionsPage extends ConsumerStatefulWidget {
  const DeviceSessionsPage({super.key});

  @override
  ConsumerState<DeviceSessionsPage> createState() => _DeviceSessionsPageState();
}

class _DeviceSessionsPageState extends ConsumerState<DeviceSessionsPage> {
  bool _loading = true;
  List<DeviceSessionDto> _sessions = const [];
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final storage = ref.read(secureStorageProvider);
      final current =
          await storage.read(key: AuthRepository.sessionIdKey) ?? '';
      final list =
          await ref.read(deviceSessionsRepositoryProvider).listActiveSessions();
      if (!mounted) return;
      setState(() {
        _currentSessionId = current.isEmpty ? null : current;
        _sessions = list;
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

  Future<void> _revoke(DeviceSessionDto s) async {
    final isCurrent =
        _currentSessionId != null && s.sessionId == _currentSessionId;
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Revoke session'),
            content: Text(
              isCurrent
                  ? 'Revoke this device session? You may be logged out.'
                  : 'Revoke this session?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Revoke'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    try {
      await ref
          .read(deviceSessionsRepositoryProvider)
          .revokeSession(s.sessionId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device sessions'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('No active sessions'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final s = _sessions[i];
                      final isCurrent = _currentSessionId != null &&
                          s.sessionId == _currentSessionId;
                      final title = s.deviceName?.trim().isNotEmpty == true
                          ? s.deviceName!.trim()
                          : 'Device ${s.deviceId}';
                      final subtitle = [
                        if (isCurrent) 'This device',
                        if (s.ipAddress != null && s.ipAddress!.isNotEmpty)
                          'IP ${s.ipAddress}',
                        'Last seen ${_fmt(s.lastSeen)}',
                        if (s.isStale) 'Stale',
                      ].join(' • ');
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: Icon(
                            isCurrent
                                ? Icons.phone_iphone_rounded
                                : Icons.devices_rounded,
                          ),
                          title: Text(title),
                          subtitle: Text(subtitle),
                          trailing: IconButton(
                            tooltip: 'Revoke',
                            icon: const Icon(Icons.logout_rounded),
                            onPressed: () => _revoke(s),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
