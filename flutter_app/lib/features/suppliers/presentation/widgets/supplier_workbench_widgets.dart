import 'package:flutter/material.dart';

import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/models.dart';

String _fmt(double value) => value.toStringAsFixed(2);

class SupplierTypeBadge extends StatelessWidget {
  const SupplierTypeBadge({
    super.key,
    required this.isMercantile,
    required this.isNonMercantile,
  });

  final bool isMercantile;
  final bool isNonMercantile;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;
    final Color fg;

    if (isMercantile && isNonMercantile) {
      label = 'Mercantile';
      bg = const Color(0xFFDCEEFF);
      fg = const Color(0xFF154067);
    } else if (isMercantile) {
      label = 'Mercantile';
      bg = const Color(0xFFDCEEFF);
      fg = const Color(0xFF154067);
    } else if (isNonMercantile) {
      label = 'Non-Mercantile';
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFF7A5300);
    } else {
      label = 'Unassigned';
      bg = const Color(0xFFEAF1F8);
      fg = const Color(0xFF23415F);
    }

    return ProfessionalBadge(
      label: label,
      backgroundColor: bg,
      foregroundColor: fg,
    );
  }
}

class SupplierStatusBadge extends StatelessWidget {
  const SupplierStatusBadge({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return ProfessionalBadge(
      label: isActive ? 'Active' : 'Inactive',
      backgroundColor:
          isActive ? const Color(0xFFDDF7E7) : const Color(0xFFFFE4D6),
      foregroundColor:
          isActive ? const Color(0xFF0E5A31) : const Color(0xFF7A3715),
    );
  }
}

class SupplierCreditChip extends StatelessWidget {
  const SupplierCreditChip({
    super.key,
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final String value;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class SupplierMetricCard extends StatelessWidget {
  const SupplierMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SupplierReviewCard extends StatelessWidget {
  const SupplierReviewCard({
    super.key,
    required this.supplier,
    required this.summary,
    this.onEdit,
    this.onRecordPayment,
    this.onViewFullDetails,
  });

  final SupplierDto supplier;
  final SupplierSummaryDto summary;
  final VoidCallback? onEdit;
  final VoidCallback? onRecordPayment;
  final VoidCallback? onViewFullDetails;

  @override
  Widget build(BuildContext context) {
    final availableCredit = (supplier.creditLimit - supplier.outstandingAmount)
        .clamp(0.0, double.infinity);
    final utilizationPct = supplier.creditLimit > 0
        ? (supplier.outstandingAmount / supplier.creditLimit * 100)
            .toStringAsFixed(1)
        : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfessionalDocumentHeader(
            title: supplier.name,
            subtitle: [
              if ((supplier.address ?? '').isNotEmpty) supplier.address!,
              if ((supplier.phone ?? '').isNotEmpty) 'Phone: ${supplier.phone}',
              if ((supplier.email ?? '').isNotEmpty) 'Email: ${supplier.email}',
            ].join(' | ').isEmpty
                ? 'Supplier #${supplier.supplierId}'
                : [
                    'Supplier #${supplier.supplierId}',
                    if ((supplier.address ?? '').isNotEmpty) supplier.address!,
                  ].join(' | '),
            badges: [
              SupplierTypeBadge(
                isMercantile: supplier.isMercantile,
                isNonMercantile: supplier.isNonMercantile,
              ),
              SupplierStatusBadge(isActive: supplier.isActive),
            ],
          ),
          const SizedBox(height: 16),
          ProfessionalSectionCard(
            title: 'Contact Details',
            child: ProfessionalFieldGrid(
              fields: [
                ProfessionalFieldGridItem(
                  label: 'Contact Person',
                  value: supplier.contactPerson ?? '',
                ),
                ProfessionalFieldGridItem(
                  label: 'Phone',
                  value: supplier.phone ?? '',
                ),
                ProfessionalFieldGridItem(
                  label: 'Email',
                  value: supplier.email ?? '',
                ),
                ProfessionalFieldGridItem(
                  label: 'Address',
                  value: supplier.address ?? '',
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ProfessionalSummaryCard(
            title: 'Financial Terms',
            rows: [
              (
                label: 'Payment Terms',
                value: '${supplier.paymentTerms} days',
                emphasize: false
              ),
              (
                label: 'Credit Limit',
                value: _fmt(supplier.creditLimit),
                emphasize: true
              ),
              (
                label: 'Outstanding',
                value: _fmt(supplier.outstandingAmount),
                emphasize: true
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProfessionalSectionCard(
            title: 'Business Summary',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossCount = constraints.maxWidth >= 400 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: crossCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  children: [
                    SupplierMetricCard(
                      title: 'Total Purchases',
                      value: _fmt(summary.totalPurchases),
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFF0E5A31),
                    ),
                    SupplierMetricCard(
                      title: 'Total Payments',
                      value: _fmt(summary.totalPayments),
                      icon: Icons.payments_rounded,
                      iconColor: const Color(0xFF154067),
                    ),
                    SupplierMetricCard(
                      title: 'Total Returns',
                      value: _fmt(summary.totalReturns),
                      icon: Icons.assignment_return_rounded,
                      iconColor: const Color(0xFF7A3715),
                    ),
                    SupplierMetricCard(
                      title: 'Debit Notes',
                      value: _fmt(summary.totalDebitNotes),
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFF443181),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ProfessionalSummaryCard(
            title: 'Payment Summary',
            rows: [
              (
                label: 'Total Purchases',
                value: _fmt(summary.totalPurchases),
                emphasize: true
              ),
              (
                label: 'Total Payments',
                value: _fmt(summary.totalPayments),
                emphasize: true
              ),
              (
                label: 'Total Returns',
                value: _fmt(summary.totalReturns),
                emphasize: false
              ),
              (
                label: 'Debit Notes',
                value: _fmt(summary.totalDebitNotes),
                emphasize: false
              ),
              (
                label: 'Outstanding Balance',
                value: _fmt(summary.outstandingBalance),
                emphasize: true
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProfessionalSummaryCard(
            title: 'Credit Status',
            rows: [
              (
                label: 'Outstanding',
                value: _fmt(supplier.outstandingAmount),
                emphasize: true
              ),
              (
                label: 'Available Credit',
                value: _fmt(availableCredit),
                emphasize: true
              ),
              (
                label: 'Credit Limit',
                value: _fmt(supplier.creditLimit),
                emphasize: false
              ),
              (
                label: 'Utilization',
                value: '$utilizationPct%',
                emphasize: false
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onEdit != null)
                FilledButton.tonalIcon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              if (onRecordPayment != null)
                FilledButton.icon(
                  onPressed: onRecordPayment,
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Record Payment'),
                ),
              if (onViewFullDetails != null)
                OutlinedButton.icon(
                  onPressed: onViewFullDetails,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Full Details'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
