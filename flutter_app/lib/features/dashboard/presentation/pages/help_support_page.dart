import 'dart:convert';
import 'dart:io';

import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../../../shared/widgets/app_confirm_dialog.dart';
import '../../data/settings_repository.dart';
import '../widgets/dashboard_sidebar.dart';
import 'sync_health_page.dart';

class HelpSupportPage extends ConsumerWidget {
  const HelpSupportPage({super.key, this.fromMenu = false, this.onMenuSelect});

  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'unknown');
  static const String buildNumber =
      String.fromEnvironment('BUILD_NUMBER', defaultValue: 'unknown');
  static const String releaseDate =
      String.fromEnvironment('RELEASE_DATE', defaultValue: 'Not configured');
  static const String releaseChannel =
      String.fromEnvironment('RELEASE_CHANNEL', defaultValue: 'Production');
  static const String updateUrl =
      String.fromEnvironment('UPDATE_URL', defaultValue: '');
  static const String updatePolicy =
      String.fromEnvironment('UPDATE_POLICY', defaultValue: '');
  static const String supportEmail =
      String.fromEnvironment('SUPPORT_EMAIL', defaultValue: '');
  static const String supportPhone =
      String.fromEnvironment('SUPPORT_PHONE', defaultValue: '');
  static const String supportWebsite =
      String.fromEnvironment('SUPPORT_WEBSITE', defaultValue: '');
  static const String supportHours =
      String.fromEnvironment('SUPPORT_HOURS', defaultValue: '');
  static const String termsUrl =
      String.fromEnvironment('SUPPORT_TERMS_URL', defaultValue: '');
  static const String privacyUrl =
      String.fromEnvironment('SUPPORT_PRIVACY_URL', defaultValue: '');

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final theme = Theme.of(context);
    final outbox = ref.watch(outboxNotifierProvider);
    final supportWebsiteDisplay = _displayUrl(supportWebsite);
    final updateUrlDisplay = _displayUrl(updateUrl);
    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !fromMenu,
        leading: fromMenu
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : (isWide ? const DesktopSidebarToggleLeading() : null),
        leadingWidth: (!fromMenu && isWide) ? 104 : null,
        title: const Text('Help & Support'),
      ),
      drawer: fromMenu
          ? DashboardSidebar(
              onSelect: (label) => onMenuSelect?.call(context, label),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Application support center',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use this page for support operations, release information, diagnostics, issue reporting, and legal guidance.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Version $appVersion+$buildNumber')),
                      Chip(label: Text(releaseChannel)),
                      Chip(
                          label:
                              Text('Queued sync items: ${outbox.queuedCount}')),
                      Chip(
                        label: Text(
                          outbox.isOnline
                              ? 'Backend reachable'
                              : 'Offline mode',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Support tools',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _HelpTile(
            icon: Icons.support_agent_rounded,
            title: 'Generate support bundle',
            subtitle:
                'Create a JSON bundle with app, outbox, and backend diagnostics to share with support.',
            onTap: () => _generateSupportBundle(context, ref),
          ),
          _HelpTile(
            icon: Icons.sync_rounded,
            title: 'Sync health',
            subtitle:
                'Inspect queued transactions, failed sync attempts, and export a sync debug bundle.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncHealthPage()),
              );
            },
          ),
          _HelpTile(
            icon: Icons.bug_report_rounded,
            title: 'Report an issue',
            subtitle:
                'Share a structured incident report with version, platform, and sync-state context.',
            onTap: () => _reportIssue(context, ref),
          ),
          const SizedBox(height: 16),
          Text(
            'Versioning & updates',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _HelpTile(
            icon: Icons.system_update_rounded,
            title: 'Version & updates',
            subtitle:
                'Review the installed build, release channel, update path, and support portal for new packages.',
            onTap: () => _showVersionAndUpdates(
              context,
              updateUrlDisplay: updateUrlDisplay,
            ),
          ),
          _HelpTile(
            icon: Icons.contact_support_rounded,
            title: 'Support contact',
            subtitle:
                'View the configured support email, phone, website, and operating hours for this build.',
            onTap: () => _showSupportContact(context),
          ),
          const SizedBox(height: 16),
          Text(
            'Policies',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _HelpTile(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy policy',
            subtitle:
                'Review how operational and diagnostic data should be handled when using support tools.',
            onTap: () => _showPolicyDialog(
              context,
              title: 'Privacy policy',
              summary: const [
                'EBS Lite processes business records required to operate an ERP environment, including company, customer, supplier, inventory, employee, transaction, accounting, workflow, and audit data.',
                'Operational data is used to deliver order processing, stock control, financial posting, reporting, support diagnosis, security monitoring, and continuity of service for authorized users.',
                'Support bundles and issue reports are intended for controlled troubleshooting. They may contain device details, queue state, redacted logs, build identifiers, and backend readiness information relevant to incident resolution.',
                'Organizations using the application are responsible for obtaining any internal or legal approvals required to collect, process, export, retain, and share business or personal data through the system.',
                'Only authorized personnel should access production data, diagnostic exports, administrative settings, or support artifacts. Shared material should be limited to the minimum information required for support resolution.',
                "Diagnostic artifacts should be transmitted only to approved support contacts and retained according to the customer organization's security, privacy, and retention policy.",
                'Where the application is used to manage employee or customer records, the customer organization remains responsible for compliance with local employment, privacy, consumer, and record-retention obligations.',
              ],
              link: privacyUrl,
            ),
          ),
          _HelpTile(
            icon: Icons.description_rounded,
            title: 'Terms of service',
            subtitle:
                'Review the expected use of the application and the handling of shared diagnostic material.',
            onTap: () => _showPolicyDialog(
              context,
              title: 'Terms of service',
              summary: const [
                'EBS Lite is intended for authorized commercial and operational ERP use, including sales, purchases, inventory, accounting, HR, reporting, workflow, and support processes approved by the customer organization.',
                'Users must access the system only with assigned credentials and permissions. Administrative actions, approval overrides, exports, and configuration changes must be performed only by personnel authorized to perform them.',
                'The customer organization is responsible for validating master data, transaction accuracy, accounting results, tax configuration, report outputs, backup procedures, and release readiness before relying on production data.',
                'The application and its exported reports, support bundles, and diagnostics must not be used for unlawful activity, unauthorized surveillance, credential sharing, data exfiltration, or misuse of regulated or confidential information.',
                'Update packages, configuration changes, and integrations should be deployed through controlled release procedures. Customers are responsible for reviewing environment-specific implications before applying changes in production.',
                'Support services rely on timely access to accurate incident details, reproducible steps, and, where required, sanitized diagnostic bundles. Resolution timelines may depend on customer responsiveness and environment access.',
                'Any customer-specific compliance, statutory reporting, archival, or regulatory obligations remain the responsibility of the customer unless separately agreed in writing.',
              ],
              link: termsUrl,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Before contacting support',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check the selected location, reproduce the issue with the exact workflow, note the affected document number, and review sync health before escalating. Include the installed version, release channel, and a support bundle whenever the issue affects sync, permissions, backend communication, posting, or update behavior.',
                  ),
                  if (supportWebsiteDisplay.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Support portal: $supportWebsiteDisplay',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }

  Future<void> _generateSupportBundle(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final outboxState = ref.read(outboxNotifierProvider);

    showAppBlockingProgressDialog(
      context,
      message: 'Generating support bundle...',
    );
    var progressDialogOpen = true;

    try {
      final failed =
          await ref.read(outboxNotifierProvider.notifier).listFailed(limit: 50);
      Map<String, dynamic>? backendBundle;
      String? backendBundleError;
      try {
        backendBundle =
            await ref.read(settingsRepositoryProvider).getSupportBundle();
      } catch (e) {
        backendBundleError = ErrorHandler.message(e);
      }

      final payload = <String, dynamic>{
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'app': {
          'version': appVersion,
          'build_number': buildNumber,
          'platform': Platform.operatingSystem,
          'platform_version': Platform.operatingSystemVersion,
        },
        'outbox': {
          'is_online': outboxState.isOnline,
          'queued_count': outboxState.queuedCount,
          'is_syncing': outboxState.isSyncing,
          'last_error': outboxState.lastError,
          'last_sync_at': outboxState.lastSyncAt?.toIso8601String(),
          'failed_items': failed
              .map((it) => {
                    'id': it.id,
                    'type': it.type,
                    'method': it.method,
                    'path': it.path,
                    'attempts': it.attempts,
                    'status': it.status,
                    'created_at_ms': it.createdAt,
                    'last_error': it.lastError,
                  })
              .toList(),
        },
        'backend': backendBundle,
        if (backendBundleError != null) 'backend_error': backendBundleError,
      };

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final filename = 'ebs_support_bundle_$ts.json';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonEncode(payload), flush: true);

      if (context.mounted) {
        Navigator.of(context).pop();
        progressDialogOpen = false;
      }

      await Share.shareXFiles(
        [XFile(file.path, name: filename, mimeType: 'application/json')],
        subject: 'EBS Lite support bundle',
        text: 'Support bundle attached.',
      );
    } catch (e) {
      if (context.mounted) {
        if (progressDialogOpen) {
          Navigator.of(context).pop();
        }
        messenger.showSnackBar(
          SnackBar(content: Text(ErrorHandler.message(e))),
        );
      }
    }
  }

  Future<void> _reportIssue(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final detailsController = TextEditingController();
    String severity = 'Normal';

    final draft = await showDialog<_IssueReportDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Report an issue'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Issue title',
                          hintText: 'POS payment failed while syncing',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: severity,
                        decoration:
                            const InputDecoration(labelText: 'Severity'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Low',
                            child: Text('Low'),
                          ),
                          DropdownMenuItem(
                            value: 'Normal',
                            child: Text('Normal'),
                          ),
                          DropdownMenuItem(
                            value: 'High',
                            child: Text('High'),
                          ),
                          DropdownMenuItem(
                            value: 'Critical',
                            child: Text('Critical'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => severity = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: detailsController,
                        minLines: 5,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'What happened?',
                          hintText:
                              'Include the page, document number, user action, and visible error.',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final details = detailsController.text.trim();
                    if (title.isEmpty || details.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Add both a title and a description.'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      _IssueReportDraft(
                        title: title,
                        severity: severity,
                        details: details,
                      ),
                    );
                  },
                  child: const Text('Share report'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    detailsController.dispose();

    if (draft == null) return;

    final outbox = ref.read(outboxNotifierProvider);
    final report = StringBuffer()
      ..writeln('EBS Lite Issue Report')
      ..writeln()
      ..writeln('Title: ${draft.title}')
      ..writeln('Severity: ${draft.severity}')
      ..writeln('Generated at: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('App version: $appVersion+$buildNumber')
      ..writeln('Platform: ${Platform.operatingSystem}')
      ..writeln('Online: ${outbox.isOnline}')
      ..writeln('Queued sync items: ${outbox.queuedCount}')
      ..writeln(
          'Last sync at: ${outbox.lastSyncAt?.toIso8601String() ?? 'Unknown'}')
      ..writeln()
      ..writeln('Details')
      ..writeln(draft.details)
      ..writeln()
      ..writeln(
          'Recommended attachment: generate and share a support bundle if backend, sync, or permissions are involved.');

    await Share.share(
      report.toString(),
      subject: 'EBS Lite issue report: ${draft.title}',
    );
  }

  Future<void> _showSupportContact(BuildContext context) async {
    final supportWebsiteDisplay = _displayUrl(supportWebsite);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Support contact'),
          content: SizedBox(
            width: 500,
            child: SelectionArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContactRow(
                    label: 'Email',
                    value:
                        supportEmail.isEmpty ? 'Not configured' : supportEmail,
                    onCopy: supportEmail.isEmpty
                        ? null
                        : () => _copyText(
                              dialogContext,
                              label: 'Support email',
                              value: supportEmail,
                            ),
                  ),
                  const SizedBox(height: 12),
                  _ContactRow(
                    label: 'Phone',
                    value:
                        supportPhone.isEmpty ? 'Not configured' : supportPhone,
                    onCopy: supportPhone.isEmpty
                        ? null
                        : () => _copyText(
                              dialogContext,
                              label: 'Support phone',
                              value: supportPhone,
                            ),
                  ),
                  const SizedBox(height: 12),
                  _ContactRow(
                    label: 'Web',
                    value: supportWebsiteDisplay.isEmpty
                        ? 'Not configured'
                        : supportWebsiteDisplay,
                    onCopy: supportWebsiteDisplay.isEmpty
                        ? null
                        : () => _copyText(
                              dialogContext,
                              label: 'Support website',
                              value: supportWebsiteDisplay,
                            ),
                  ),
                  const SizedBox(height: 12),
                  _ContactRow(
                    label: 'Hours',
                    value:
                        supportHours.isEmpty ? 'Not configured' : supportHours,
                  ),
                  if (supportEmail.isEmpty &&
                      supportPhone.isEmpty &&
                      supportWebsite.isEmpty &&
                      supportHours.isEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Support contact details are not configured for this build. Add SUPPORT_EMAIL, SUPPORT_PHONE, SUPPORT_WEBSITE, and SUPPORT_HOURS in the release dart defines.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showVersionAndUpdates(
    BuildContext context, {
    required String updateUrlDisplay,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final effectivePolicy = updatePolicy.trim().isEmpty
            ? 'Updates should be deployed through approved release procedures after environment validation, operator communication, and backup verification.'
            : updatePolicy.trim();
        return AlertDialog(
          title: const Text('Version & updates'),
          content: SizedBox(
            width: 560,
            child: SelectionArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _VersionRow(label: 'Application', value: 'EBS Lite'),
                    const SizedBox(height: 12),
                    _VersionRow(label: 'Version', value: appVersion),
                    const SizedBox(height: 12),
                    _VersionRow(label: 'Build', value: buildNumber),
                    const SizedBox(height: 12),
                    _VersionRow(label: 'Channel', value: releaseChannel),
                    const SizedBox(height: 12),
                    _VersionRow(label: 'Release date', value: releaseDate),
                    const SizedBox(height: 18),
                    Text(
                      'Update guidance',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(effectivePolicy),
                    if (updateUrlDisplay.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _VersionRow(
                        label: 'Update source',
                        value: updateUrlDisplay,
                        onCopy: () => _copyText(
                          dialogContext,
                          label: 'Update source',
                          value: updateUrlDisplay,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _copyText(
                dialogContext,
                label: 'Build details',
                value:
                    'EBS Lite $appVersion+$buildNumber | $releaseChannel | $releaseDate',
              ),
              child: const Text('Copy build info'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPolicyDialog(
    BuildContext context, {
    required String title,
    required List<String> summary,
    required String link,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 540,
            child: SelectionArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in summary) ...[
                      Text(item),
                      const SizedBox(height: 10),
                    ],
                    if (link.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Configured reference',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(link),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            if (link.trim().isNotEmpty)
              TextButton(
                onPressed: () => _copyText(
                  dialogContext,
                  label: title,
                  value: link.trim(),
                ),
                child: const Text('Copy link'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copyText(
    BuildContext context, {
    required String label,
    required String value,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  String _displayUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed
        .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
        .replaceAll(RegExp(r'/$'), '');
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: SelectableText(value)),
        if (onCopy != null)
          IconButton(
            tooltip: 'Copy $label',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
      ],
    );
  }
}

class _IssueReportDraft {
  const _IssueReportDraft({
    required this.title,
    required this.severity,
    required this.details,
  });

  final String title;
  final String severity;
  final String details;
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: SelectableText(value)),
        if (onCopy != null)
          IconButton(
            tooltip: 'Copy $label',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
      ],
    );
  }
}
