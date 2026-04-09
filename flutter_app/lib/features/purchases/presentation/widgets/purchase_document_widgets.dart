import 'package:flutter/material.dart';

import '../../../../shared/widgets/professional_document_widgets.dart';

class PurchaseDocumentMetricCard extends StatelessWidget {
  const PurchaseDocumentMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.tint = const Color(0xFFEAF1F8),
    this.foreground = const Color(0xFF23415F),
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color tint;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: foreground,
                      ),
                ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground.withValues(alpha: 0.82),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

ProfessionalBadge purchaseStatusBadge(String status) {
  final normalized = status.trim().toUpperCase();
  switch (normalized) {
    case 'RECEIVED':
      return const ProfessionalBadge(
        label: 'Received',
        backgroundColor: Color(0xFFE8F3EC),
        foregroundColor: Color(0xFF255C35),
      );
    case 'PARTIALLY_RECEIVED':
      return const ProfessionalBadge(
        label: 'Partially Received',
        backgroundColor: Color(0xFFFFF1D6),
        foregroundColor: Color(0xFF8A5200),
      );
    case 'APPROVED':
      return const ProfessionalBadge(
        label: 'Approved',
        backgroundColor: Color(0xFFE3F0FF),
        foregroundColor: Color(0xFF1B4F8C),
      );
    case 'PENDING':
      return const ProfessionalBadge(
        label: 'Pending',
        backgroundColor: Color(0xFFFFF1D6),
        foregroundColor: Color(0xFF8A5200),
      );
    case 'DRAFT':
      return const ProfessionalBadge(
        label: 'Draft',
        backgroundColor: Color(0xFFEAF1F8),
        foregroundColor: Color(0xFF23415F),
      );
    default:
      return ProfessionalBadge(
        label: normalized.isEmpty ? 'Open' : normalized.replaceAll('_', ' '),
      );
  }
}

class PurchaseDocumentListCard extends StatelessWidget {
  const PurchaseDocumentListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badges,
    this.trailing,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Widget> badges;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.32)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.55)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            if (subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: badges,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
