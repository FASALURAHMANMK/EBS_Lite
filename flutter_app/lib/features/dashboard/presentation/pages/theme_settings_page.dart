import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme_notifier.dart';

class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  Widget _tile({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeMode current,
    required ThemeMode value,
    required String title,
    required String subtitle,
  }) {
    final selected = current == value;
    return ListTile(
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      selected: selected,
      onTap: () => ref.read(themeNotifierProvider.notifier).setMode(value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeNotifierProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(
            context: context,
            ref: ref,
            current: mode,
            value: ThemeMode.system,
            title: 'System',
            subtitle: 'Follow device setting',
          ),
          const SizedBox(height: 12),
          Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                _tile(
                  context: context,
                  ref: ref,
                  current: mode,
                  value: ThemeMode.light,
                  title: 'Light',
                  subtitle: 'Always light',
                ),
                const Divider(height: 1),
                _tile(
                  context: context,
                  ref: ref,
                  current: mode,
                  value: ThemeMode.dark,
                  title: 'Dark',
                  subtitle: 'Always dark',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
