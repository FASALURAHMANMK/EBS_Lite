import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ebs_lite/features/security/presentation/pages/device_sessions_page.dart';
import '../../data/settings_models.dart';
import '../../data/settings_repository.dart';

class SecuritySettingsPage extends ConsumerStatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  ConsumerState<SecuritySettingsPage> createState() =>
      _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage> {
  bool _loading = true;
  bool _saving = false;

  bool _allowRemote = false;
  bool _limitEnabled = false;
  final _maxSessions = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _maxSessions.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final results = await Future.wait([
        repo.getDeviceControlSettings(),
        repo.getSessionLimit(),
      ]);
      final device = results[0] as DeviceControlSettingsDto;
      final limit = results[1] as SessionLimitDto;
      if (!mounted) return;
      setState(() {
        _allowRemote = device.allowRemote;
        _limitEnabled = limit.maxSessions > 0;
        _maxSessions.text = limit.maxSessions > 0 ? '${limit.maxSessions}' : '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.updateDeviceControlSettings(
        DeviceControlSettingsDto(allowRemote: _allowRemote),
      );

      if (_limitEnabled) {
        final raw = _maxSessions.text.trim();
        final max = int.tryParse(raw) ?? 0;
        if (max <= 0) {
          throw Exception('Max sessions must be > 0');
        }
        await repo.setSessionLimit(max);
      } else {
        await repo.deleteSessionLimit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Sessions'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _allowRemote,
                        onChanged: (v) => setState(() => _allowRemote = v),
                        title: const Text('Allow remote access'),
                        subtitle:
                            const Text('Enable remote device control features'),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _limitEnabled,
                        onChanged: (v) => setState(() => _limitEnabled = v),
                        title: const Text('Session limit'),
                        subtitle:
                            const Text('Limit maximum concurrent sessions'),
                      ),
                      if (_limitEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: TextField(
                            controller: _maxSessions,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Max sessions',
                              helperText: 'Example: 5',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.devices_rounded),
                  title: const Text('Device sessions'),
                  subtitle:
                      const Text('View and revoke active device sessions'),
                  tileColor: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DeviceSessionsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
