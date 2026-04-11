import 'package:flutter/material.dart';

import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/models.dart';

String _fmt(double value) => value.toStringAsFixed(2);

class CustomerTypeBadge extends StatelessWidget {
  const CustomerTypeBadge({super.key, required this.customerType});

  final String customerType;

  @override
  Widget build(BuildContext context) {
    final normalized = customerType.trim().toUpperCase();
    final colors = switch (normalized) {
      'B2B' => (bg: const Color(0xFFDCEEFF), fg: const Color(0xFF154067)),
      'RETAIL' => (bg: const Color(0xFFDDF7E7), fg: const Color(0xFF0E5A31)),
      _ => (bg: const Color(0xFFEAF1F8), fg: const Color(0xFF23415F)),
    };
    return ProfessionalBadge(
      label: normalized.isEmpty ? 'CUSTOMER' : normalized,
      backgroundColor: colors.bg,
      foregroundColor: colors.fg,
    );
  }
}

class CustomerStatusBadge extends StatelessWidget {
  const CustomerStatusBadge({super.key, required this.isActive});

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

class CustomerCreditChip extends StatelessWidget {
  const CustomerCreditChip({
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

class CustomerMetricCard extends StatelessWidget {
  const CustomerMetricCard({
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

class CustomerReviewCard extends StatelessWidget {
  const CustomerReviewCard({
    super.key,
    required this.customer,
    required this.summary,
    this.onEdit,
    this.onRecordCollection,
    this.onViewFullDetails,
  });

  final CustomerDto customer;
  final CustomerSummaryDto summary;
  final VoidCallback? onEdit;
  final VoidCallback? onRecordCollection;
  final VoidCallback? onViewFullDetails;

  @override
  Widget build(BuildContext context) {
    final outstanding =
        customer.creditBalance > 0 ? customer.creditBalance : 0.0;
    final availableCredit = (customer.creditLimit - customer.creditBalance)
        .clamp(0.0, double.infinity);
    final utilizationPct = customer.creditLimit > 0
        ? (customer.creditBalance / customer.creditLimit * 100)
            .toStringAsFixed(1)
        : '0.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfessionalDocumentHeader(
            title: customer.name,
            subtitle: [
              if ((customer.address ?? '').isNotEmpty) customer.address!,
              if ((customer.phone ?? '').isNotEmpty) 'Phone: ${customer.phone}',
              if ((customer.email ?? '').isNotEmpty) 'Email: ${customer.email}',
            ].join(' | ').isEmpty
                ? 'Customer #${customer.customerId}'
                : [
                    'Customer #${customer.customerId}',
                    if ((customer.address ?? '').isNotEmpty) customer.address!,
                  ].join(' | '),
            badges: [
              CustomerTypeBadge(customerType: customer.customerType),
              CustomerStatusBadge(isActive: customer.isActive),
            ],
          ),
          const SizedBox(height: 16),
          ProfessionalSectionCard(
            title: 'Contact Details',
            child: ProfessionalFieldGrid(
              fields: [
                ProfessionalFieldGridItem(
                  label: 'Contact Person',
                  value: customer.contactPerson ?? '',
                ),
                ProfessionalFieldGridItem(
                  label: 'Phone',
                  value: customer.phone ?? '',
                ),
                ProfessionalFieldGridItem(
                  label: 'Email',
                  value: customer.email ?? '',
                ),
                ProfessionalFieldGridItem(
                  label: 'Address',
                  value: customer.address ?? '',
                  maxLines: 2,
                ),
                ProfessionalFieldGridItem(
                  label: 'Shipping Address',
                  value: customer.shippingAddress ?? '',
                  maxLines: 2,
                ),
                ProfessionalFieldGridItem(
                  label: 'Tax Number',
                  value: customer.taxNumber ?? '',
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
                value: '${customer.paymentTerms} days',
                emphasize: false
              ),
              (
                label: 'Credit Limit',
                value: _fmt(customer.creditLimit),
                emphasize: true
              ),
              (
                label: 'Credit Balance',
                value: _fmt(customer.creditBalance),
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
                    CustomerMetricCard(
                      title: 'Total Sales',
                      value: _fmt(summary.totalSales),
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFF0E5A31),
                    ),
                    CustomerMetricCard(
                      title: 'Total Payments',
                      value: _fmt(summary.totalPayments),
                      icon: Icons.payments_rounded,
                      iconColor: const Color(0xFF154067),
                    ),
                    CustomerMetricCard(
                      title: 'Total Returns',
                      value: _fmt(summary.totalReturns),
                      icon: Icons.assignment_return_rounded,
                      iconColor: const Color(0xFF7A3715),
                    ),
                    CustomerMetricCard(
                      title: 'Loyalty Points',
                      value: summary.loyaltyPoints.toStringAsFixed(0),
                      icon: Icons.loyalty_rounded,
                      iconColor: const Color(0xFF443181),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ProfessionalSummaryCard(
            title: 'Credit Status',
            rows: [
              (label: 'Outstanding', value: _fmt(outstanding), emphasize: true),
              (
                label: 'Available Credit',
                value: _fmt(availableCredit),
                emphasize: true
              ),
              (
                label: 'Credit Limit',
                value: _fmt(customer.creditLimit),
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
              if (onRecordCollection != null)
                FilledButton.icon(
                  onPressed: onRecordCollection,
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Record Collection'),
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
