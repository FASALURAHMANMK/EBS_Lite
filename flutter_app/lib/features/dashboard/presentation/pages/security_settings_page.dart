import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/manager_override_dialog.dart';
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
  final _minPasswordLength = TextEditingController();
  final _sessionIdleTimeoutMins = TextEditingController();
  final _elevatedAccessWindowMins = TextEditingController();
  bool _requireUppercase = true;
  bool _requireLowercase = true;
  bool _requireNumber = true;
  bool _requireSpecial = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _maxSessions.dispose();
    _minPasswordLength.dispose();
    _sessionIdleTimeoutMins.dispose();
    _elevatedAccessWindowMins.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      final results = await Future.wait([
        repo.getDeviceControlSettings(),
        repo.getSessionLimit(),
        repo.getSecurityPolicy(),
      ]);
      final device = results[0] as DeviceControlSettingsDto;
      final limit = results[1] as SessionLimitDto;
      final policy = results[2] as SecurityPolicyDto;
      if (!mounted) return;
      setState(() {
        _allowRemote = device.allowRemote;
        _limitEnabled = limit.maxSessions > 0;
        _maxSessions.text = limit.maxSessions > 0 ? '${limit.maxSessions}' : '';
        _minPasswordLength.text = '${policy.minPasswordLength}';
        _sessionIdleTimeoutMins.text = '${policy.sessionIdleTimeoutMins}';
        _elevatedAccessWindowMins.text = '${policy.elevatedAccessWindowMins}';
        _requireUppercase = policy.requireUppercase;
        _requireLowercase = policy.requireLowercase;
        _requireNumber = policy.requireNumber;
        _requireSpecial = policy.requireSpecial;
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
    setState(() => _saving = true);
    try {
      final stepUp = await showManagerOverrideDialog(
        context,
        ref,
        title: 'Confirm security changes',
        requiredPermissions: const ['MANAGE_SETTINGS'],
        identityLabel: 'Admin username or email',
        actionLabel: 'Confirm',
      );
      if (stepUp == null) {
        return;
      }

      final repo = ref.read(settingsRepositoryProvider);
      await repo.updateDeviceControlSettings(
        DeviceControlSettingsDto(allowRemote: _allowRemote),
        stepUpToken: stepUp.overrideToken,
      );

      if (_limitEnabled) {
        final raw = _maxSessions.text.trim();
        final max = int.tryParse(raw) ?? 0;
        if (max <= 0) {
          throw Exception('Max sessions must be > 0');
        }
        await repo.setSessionLimit(
          max,
          stepUpToken: stepUp.overrideToken,
        );
      } else {
        await repo.deleteSessionLimit(stepUpToken: stepUp.overrideToken);
      }

      final minPasswordLength =
          int.tryParse(_minPasswordLength.text.trim()) ?? 0;
      final sessionIdleTimeout =
          int.tryParse(_sessionIdleTimeoutMins.text.trim()) ?? 0;
      final elevatedWindow =
          int.tryParse(_elevatedAccessWindowMins.text.trim()) ?? 0;
      if (minPasswordLength < 8) {
        throw Exception('Minimum password length must be at least 8');
      }
      if (sessionIdleTimeout < 5) {
        throw Exception('Session idle timeout must be at least 5 minutes');
      }
      if (elevatedWindow < 1) {
        throw Exception('Elevated access window must be at least 1 minute');
      }
      await repo.updateSecurityPolicy(
        SecurityPolicyDto(
          minPasswordLength: minPasswordLength,
          requireUppercase: _requireUppercase,
          requireLowercase: _requireLowercase,
          requireNumber: _requireNumber,
          requireSpecial: _requireSpecial,
          sessionIdleTimeoutMins: sessionIdleTimeout,
          elevatedAccessWindowMins: elevatedWindow,
        ),
        stepUpToken: stepUp.overrideToken,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Saved')));
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
                      ListTile(
                        title: const Text('Elevated protection'),
                        subtitle: const Text(
                          'Saving this page requires short-lived admin step-up verification.',
                        ),
                        leading: const Icon(Icons.verified_user_rounded),
                      ),
                      const Divider(height: 1),
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
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password policy',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'New registrations and password resets must satisfy this policy.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _minPasswordLength,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Minimum password length',
                            helperText: 'Recommended: 10 or more',
                          ),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _requireUppercase,
                          onChanged: (v) =>
                              setState(() => _requireUppercase = v ?? true),
                          title: const Text('Require uppercase letter'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          value: _requireLowercase,
                          onChanged: (v) =>
                              setState(() => _requireLowercase = v ?? true),
                          title: const Text('Require lowercase letter'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          value: _requireNumber,
                          onChanged: (v) =>
                              setState(() => _requireNumber = v ?? true),
                          title: const Text('Require number'),
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          value: _requireSpecial,
                          onChanged: (v) =>
                              setState(() => _requireSpecial = v ?? true),
                          title: const Text('Require special character'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session policy',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Inactive sessions are revoked server-side. Elevated approval tokens use the access window below.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _sessionIdleTimeoutMins,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Session idle timeout (minutes)',
                            helperText: 'Example: 480 for an 8-hour workday',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _elevatedAccessWindowMins,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Elevated access window (minutes)',
                            helperText:
                                'Short-lived admin re-auth window for sensitive changes',
                          ),
                        ),
                      ],
                    ),
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
