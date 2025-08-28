import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      _NotificationItem(
        title: 'Low stock alert: Item A',
        body: 'Stock below threshold at Main Warehouse.',
        time: 'Just now',
        unread: true,
        icon: Icons.inventory_2_rounded,
      ),
      _NotificationItem(
        title: 'Payment received',
        body: 'Invoice INV-0921 has been paid.',
        time: '1h ago',
        unread: false,
        icon: Icons.payments_rounded,
      ),
      _NotificationItem(
        title: 'New customer registered',
        body: 'Acme Traders has joined your workspace.',
        time: 'Yesterday',
        unread: false,
        icon: Icons.person_add_alt_1_rounded,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final n = items[index];
          return Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(.12),
                child: Icon(n.icon, color: theme.colorScheme.primary),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      n.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (n.unread)
                    Container(
                      height: 8,
                      width: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                '${n.body}\n${n.time}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}

class _NotificationItem {
  final String title;
  final String body;
  final String time;
  final bool unread;
  final IconData icon;

  _NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.unread,
    required this.icon,
  });
}

