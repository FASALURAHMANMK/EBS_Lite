import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardHeader extends ConsumerWidget implements PreferredSizeWidget {
  const DashboardHeader({super.key, this.onToggleTheme});

  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Placeholder values; replace with actual data providers
    const isOnline = true;
    String selectedLocation = 'Location 1';
    String selectedLang = 'English';

    return AppBar(
      automaticallyImplyLeading: true,
      titleSpacing: 0,
      title: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.business, color: Colors.red),
          const SizedBox(width: 8),
          const Text('Company', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: selectedLocation,
            underline: const SizedBox(),
            dropdownColor: theme.colorScheme.surface,
            onChanged: (_) {},
            items: const [
              DropdownMenuItem(value: 'Location 1', child: Text('Location 1')),
              DropdownMenuItem(value: 'Location 2', child: Text('Location 2')),
            ],
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Icon(isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: isOnline ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(theme.brightness == Brightness.dark
                  ? Icons.dark_mode
                  : Icons.light_mode),
              onPressed: onToggleTheme,
            ),
            DropdownButton<String>(
              value: selectedLang,
              underline: const SizedBox(),
              dropdownColor: theme.colorScheme.surface,
              onChanged: (_) {},
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: 'Spanish', child: Text('Spanish')),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
