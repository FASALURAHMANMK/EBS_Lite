import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/dashboard_customization_notifier.dart';
import '../../controllers/ui_prefs_notifier.dart';
import '../dashboard_actions.dart';

class DashboardCustomizationPage extends ConsumerWidget {
  const DashboardCustomizationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cfg = ref.watch(dashboardCustomizationProvider);
    final cfgNotifier = ref.read(dashboardCustomizationProvider.notifier);
    final showQuick = ref.watch(quickActionVisibilityProvider);

    final selectedShortcuts = cfg.shortcutActionIds
        .where((id) => dashboardActionForId(id) != null)
        .toSet();

    final quickActionId = (cfg.quickActionId != null &&
            dashboardActionForId(cfg.quickActionId!) != null)
        ? cfg.quickActionId
        : null;

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Text(
            text,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          TextButton(
            onPressed: () async {
              await cfgNotifier.resetToDefaults();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                    const SnackBar(content: Text('Reset to defaults')));
            },
            child: const Text('Reset'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          sectionTitle('Quick Action Button'),
          SwitchListTile.adaptive(
            value: showQuick,
            onChanged: (v) =>
                ref.read(quickActionVisibilityProvider.notifier).setVisible(v),
            title: const Text('Show Quick Action Button'),
            subtitle: const Text('Floating button for one configured action'),
            secondary: const Icon(Icons.bolt_rounded),
            tileColor: theme.colorScheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Quick action',
              helperText: 'Tapping the button runs this action',
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: quickActionId,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...dashboardActions.map(
                    (a) => DropdownMenuItem<String?>(
                      value: a.id,
                      child: Row(
                        children: [
                          Icon(a.icon, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(a.label)),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (v) async => cfgNotifier.setQuickAction(v),
              ),
            ),
          ),
          const SizedBox(height: 20),
          sectionTitle('Dashboard Shortcuts'),
          Text(
            'Choose which shortcuts appear on your dashboard.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ...dashboardActions.map((a) {
            final selected = selectedShortcuts.contains(a.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CheckboxListTile(
                value: selected,
                onChanged: (v) async {
                  final next = <String>[
                    ...cfg.shortcutActionIds
                        .where((id) => dashboardActionForId(id) != null),
                  ];
                  next.removeWhere((id) => id == a.id);
                  if (v == true) next.add(a.id);
                  await cfgNotifier.setShortcuts(next);
                },
                secondary: Icon(a.icon),
                title: Text(a.label),
                subtitle: a.requiresLocation
                    ? const Text('Requires a selected location')
                    : null,
                tileColor: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            );
          }),
          if (selectedShortcuts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No shortcuts enabled. The shortcuts section will be hidden on the dashboard.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
