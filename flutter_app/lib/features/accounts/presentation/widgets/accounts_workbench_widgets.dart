import 'package:flutter/material.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import '../../data/models.dart';

String formatAccountDisplayTitle({
  String? accountCode,
  String? accountName,
  int? accountId,
}) {
  final parts = <String>[
    if ((accountCode ?? '').trim().isNotEmpty) accountCode!.trim(),
    if ((accountName ?? '').trim().isNotEmpty) accountName!.trim(),
  ];
  if (parts.isEmpty) {
    return accountId == null ? 'Account' : 'Account #$accountId';
  }
  return parts.join(' ');
}

String formatVoucherDisplayTitle({
  required String type,
  required String reference,
  int? voucherId,
}) {
  final normalizedType = type.trim().toUpperCase();
  final normalizedReference = reference.trim();
  if (normalizedReference.isNotEmpty) {
    if (normalizedType.isEmpty) return normalizedReference;
    return '$normalizedType • $normalizedReference';
  }
  if (voucherId != null) {
    return normalizedType.isEmpty
        ? 'Voucher #$voucherId'
        : '$normalizedType #$voucherId';
  }
  return normalizedType.isEmpty ? 'Voucher' : normalizedType;
}

class AccountTypeBadge extends StatelessWidget {
  const AccountTypeBadge({
    super.key,
    required this.type,
  });

  final String type;

  @override
  Widget build(BuildContext context) {
    final normalized = type.trim().toUpperCase();
    final colors = switch (normalized) {
      'ASSET' => (bg: const Color(0xFFDCEEFF), fg: const Color(0xFF154067)),
      'LIABILITY' => (bg: const Color(0xFFFFE4D6), fg: const Color(0xFF7A3715)),
      'EQUITY' => (bg: const Color(0xFFE6E1FF), fg: const Color(0xFF443181)),
      'REVENUE' => (bg: const Color(0xFFDDF7E7), fg: const Color(0xFF0E5A31)),
      'EXPENSE' => (bg: const Color(0xFFFFE6EC), fg: const Color(0xFF7C2140)),
      _ => (bg: const Color(0xFFEAF1F8), fg: const Color(0xFF23415F)),
    };
    return ProfessionalBadge(
      label: normalized.isEmpty ? 'ACCOUNT' : normalized,
      backgroundColor: colors.bg,
      foregroundColor: colors.fg,
    );
  }
}

class AccountStatusBadge extends StatelessWidget {
  const AccountStatusBadge({
    super.key,
    required this.isActive,
  });

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

class VoucherTypeBadge extends StatelessWidget {
  const VoucherTypeBadge({
    super.key,
    required this.type,
  });

  final String type;

  @override
  Widget build(BuildContext context) {
    final normalized = type.trim().toUpperCase();
    final colors = switch (normalized) {
      'PAYMENT' => (bg: const Color(0xFFDDF7E7), fg: const Color(0xFF0E5A31)),
      'RECEIPT' => (bg: const Color(0xFFDCEEFF), fg: const Color(0xFF154067)),
      'JOURNAL' => (bg: const Color(0xFFFFF0D8), fg: const Color(0xFF774314)),
      _ => (bg: const Color(0xFFEAF1F8), fg: const Color(0xFF23415F)),
    };
    return ProfessionalBadge(
      label: normalized.isEmpty ? 'VOUCHER' : normalized,
      backgroundColor: colors.bg,
      foregroundColor: colors.fg,
    );
  }
}

class VoucherLineReviewCard extends StatelessWidget {
  const VoucherLineReviewCard({
    super.key,
    required this.line,
  });

  final VoucherLineDto line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = (line.description ?? '').trim();
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  formatAccountDisplayTitle(
                    accountCode: line.accountCode,
                    accountName: line.accountName,
                    accountId: line.accountId,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                ProfessionalBadge(label: 'Line ${line.lineNo}'),
                ProfessionalBadge(label: 'Acct #${line.accountId}'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AmountChip(
                  label: 'Debit',
                  value: line.debit.toStringAsFixed(2),
                  backgroundColor: const Color(0xFFDDF7E7),
                  foregroundColor: const Color(0xFF0E5A31),
                ),
                _AmountChip(
                  label: 'Credit',
                  value: line.credit.toStringAsFixed(2),
                  backgroundColor: const Color(0xFFFFE4D6),
                  foregroundColor: const Color(0xFF7A3715),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LedgerEntryReviewCard extends StatelessWidget {
  const LedgerEntryReviewCard({
    super.key,
    required this.entry,
    required this.localePrefs,
  });

  final LedgerEntryDto entry;
  final LocalePreferencesState localePrefs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = (entry.description ?? '').trim();
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  AppDateTime.formatDate(context, localePrefs, entry.date),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                ProfessionalBadge(label: 'Entry #${entry.entryId}'),
                if ((entry.transactionType ?? '').trim().isNotEmpty)
                  ProfessionalBadge(
                    label: entry.transactionType!.trim().toUpperCase(),
                    backgroundColor: const Color(0xFFEAF1F8),
                    foregroundColor: const Color(0xFF23415F),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _referenceBadges(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AmountChip(
                  label: 'Debit',
                  value: entry.debit.toStringAsFixed(2),
                  backgroundColor: const Color(0xFFDDF7E7),
                  foregroundColor: const Color(0xFF0E5A31),
                ),
                _AmountChip(
                  label: 'Credit',
                  value: entry.credit.toStringAsFixed(2),
                  backgroundColor: const Color(0xFFFFE4D6),
                  foregroundColor: const Color(0xFF7A3715),
                ),
                _AmountChip(
                  label: 'Balance',
                  value: entry.balance.toStringAsFixed(2),
                  backgroundColor: const Color(0xFFEAF1F8),
                  foregroundColor: const Color(0xFF23415F),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _referenceBadges() {
    final badges = <Widget>[];
    if (entry.voucher != null) {
      badges.add(
        ProfessionalBadge(
          label:
              'Voucher ${entry.voucher!.type.toUpperCase()} ${entry.voucher!.reference}',
          backgroundColor: const Color(0xFFDCEEFF),
          foregroundColor: const Color(0xFF154067),
        ),
      );
    }
    if (entry.sale != null) {
      badges.add(
        const ProfessionalBadge(
          label: 'Linked sale',
          backgroundColor: Color(0xFFE6F5E9),
          foregroundColor: Color(0xFF1C5A32),
        ),
      );
      badges.add(
        ProfessionalBadge(
          label: entry.sale!.saleNumber,
          backgroundColor: const Color(0xFFE6F5E9),
          foregroundColor: const Color(0xFF1C5A32),
        ),
      );
    }
    if (entry.purchase != null) {
      badges.add(
        const ProfessionalBadge(
          label: 'Linked purchase',
          backgroundColor: Color(0xFFFFF0D8),
          foregroundColor: Color(0xFF774314),
        ),
      );
      badges.add(
        ProfessionalBadge(
          label: entry.purchase!.purchaseNumber,
          backgroundColor: const Color(0xFFFFF0D8),
          foregroundColor: const Color(0xFF774314),
        ),
      );
    }
    if (badges.isEmpty) {
      badges.add(
        const ProfessionalBadge(
          label: 'Manual adjustment',
          backgroundColor: Color(0xFFF1F3F5),
          foregroundColor: Color(0xFF495057),
        ),
      );
    }
    return badges;
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
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
