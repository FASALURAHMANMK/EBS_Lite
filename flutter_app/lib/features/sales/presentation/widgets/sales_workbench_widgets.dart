import 'package:flutter/material.dart';

class SalesWorkbenchPane extends StatelessWidget {
  const SalesWorkbenchPane({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerTrailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (headerTrailing != null) ...[
                  const SizedBox(width: 8),
                  headerTrailing!,
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class SalesTransactionTypeChip extends StatelessWidget {
  const SalesTransactionTypeChip({
    super.key,
    required this.transactionType,
  });

  final String transactionType;

  @override
  Widget build(BuildContext context) {
    final isB2B = transactionType.trim().toUpperCase() == 'B2B';
    final bg = isB2B ? const Color(0xFF183657) : const Color(0xFF2A3622);
    final fg = isB2B ? const Color(0xFFA9D5FF) : const Color(0xFFBDE7A3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        transactionType,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class SalesStatusChip extends StatelessWidget {
  const SalesStatusChip({
    super.key,
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();
    final colors = switch (normalized) {
      'COMPLETED' => (bg: const Color(0xFF113826), fg: const Color(0xFF8EE6B0)),
      'ACTIVE' => (bg: const Color(0xFF11304A), fg: const Color(0xFF8FC8FF)),
      'SENT' => (bg: const Color(0xFF183657), fg: const Color(0xFFA9D5FF)),
      'ACCEPTED' => (bg: const Color(0xFF0D4A38), fg: const Color(0xFF99F6D5)),
      'CONVERTED' => (bg: const Color(0xFF4A2E0F), fg: const Color(0xFFF4C985)),
      'HOLD' || 'HELD' => (
          bg: const Color(0xFF4B3310),
          fg: const Color(0xFFF1C87A),
        ),
      'DRAFT' => (bg: const Color(0xFF353535), fg: const Color(0xFFE0E0E0)),
      'CANCELLED' || 'VOIDED' => (
          bg: const Color(0xFF4A1717),
          fg: const Color(0xFFFF9A9A),
        ),
      'PAID' => (bg: const Color(0xFF0D4A38), fg: const Color(0xFF99F6D5)),
      _ => (bg: const Color(0xFF30343A), fg: const Color(0xFFD8DEE9)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class SalesRefundStateChip extends StatelessWidget {
  const SalesRefundStateChip({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF17324C),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF9ED0FF),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
