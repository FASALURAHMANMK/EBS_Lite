import 'package:flutter/material.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import 'sales_workbench_widgets.dart';

class QuoteDocumentSnapshot {
  const QuoteDocumentSnapshot(this.raw);

  final Map<String, dynamic> raw;

  int? get quoteId => (raw['quote_id'] as num?)?.toInt();
  int? get customerId => (raw['customer_id'] as num?)?.toInt();
  int? get convertedSaleId => (raw['converted_sale_id'] as num?)?.toInt();
  String get number => raw['quote_number']?.toString().trim() ?? '';
  String get status => (raw['status']?.toString() ?? 'DRAFT').trim();
  String get transactionType =>
      (raw['transaction_type']?.toString() ?? 'B2B').trim();
  String get notes => raw['notes']?.toString().trim() ?? '';
  double get subtotal => (raw['subtotal'] as num?)?.toDouble() ?? 0;
  double get taxAmount => (raw['tax_amount'] as num?)?.toDouble() ?? 0;
  double get discountAmount =>
      (raw['discount_amount'] as num?)?.toDouble() ?? 0;
  double get totalAmount => (raw['total_amount'] as num?)?.toDouble() ?? 0;
  DateTime? get quoteDate =>
      DateTime.tryParse(raw['quote_date']?.toString() ?? '');
  DateTime? get validUntil =>
      DateTime.tryParse(raw['valid_until']?.toString() ?? '');
  Map<String, dynamic>? get customer =>
      raw['customer'] is Map<String, dynamic> ? raw['customer'] : null;
  List<Map<String, dynamic>> get items =>
      (raw['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  bool get isConverted => convertedSaleId != null || status == 'CONVERTED';

  String get title =>
      number.isEmpty ? (quoteId == null ? 'Quote' : 'Quote #$quoteId') : number;

  String get customerLabel {
    final nested = customer?['name']?.toString().trim() ?? '';
    if (nested.isNotEmpty) return nested;
    if ((customerId ?? 0) > 0) return 'Customer #$customerId';
    return transactionType.toUpperCase() == 'RETAIL'
        ? 'Retail quote'
        : 'B2B quote';
  }

  String get convertedBannerMessage => convertedSaleId == null
      ? 'This quote is now read-only.'
      : 'Sale #$convertedSaleId created. This quote is now read-only.';
}

class QuoteWorkbenchListTile extends StatelessWidget {
  const QuoteWorkbenchListTile({
    super.key,
    required this.quote,
    required this.localePrefs,
    required this.selected,
    required this.onTap,
  });

  final QuoteDocumentSnapshot quote;
  final LocalePreferencesState localePrefs;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
          : colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  selected ? colorScheme.primary : colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.request_quote_rounded,
                    size: 16,
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      quote.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SalesStatusChip(status: quote.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                quote.customerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 3),
              Text(
                formatQuoteDate(context, localePrefs, quote.quoteDate),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SalesTransactionTypeChip(
                    transactionType: quote.transactionType,
                  ),
                  const Spacer(),
                  Text(
                    formatQuoteMoney(quote.totalAmount),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuoteDocumentHeaderCard extends StatelessWidget {
  const QuoteDocumentHeaderCard({
    super.key,
    required this.quote,
  });

  final QuoteDocumentSnapshot quote;

  @override
  Widget build(BuildContext context) {
    final subtitle = quote.isConverted
        ? 'Converted quotes keep source, customer, and commercial totals visible before sharing or tracing the resulting sale.'
        : 'Review customer, status, validity, and line-level totals before sending, accepting, or converting this quote.';
    return ProfessionalDocumentHeader(
      title: quote.title,
      subtitle: subtitle,
      badges: [
        SalesTransactionTypeChip(transactionType: quote.transactionType),
        SalesStatusChip(status: quote.status),
        if (quote.isConverted)
          const ProfessionalBadge(
            label: 'Read Only',
            backgroundColor: Color(0xFFFFF1D6),
            foregroundColor: Color(0xFF8A5200),
          ),
      ],
    );
  }
}

class QuoteConvertedBanner extends StatelessWidget {
  const QuoteConvertedBanner({
    super.key,
    required this.quote,
  });

  final QuoteDocumentSnapshot quote;

  @override
  Widget build(BuildContext context) {
    if (!quote.isConverted) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.lock_rounded),
        title: const Text('Converted to Sale'),
        subtitle: Text(quote.convertedBannerMessage),
      ),
    );
  }
}

class QuoteOverviewSection extends StatelessWidget {
  const QuoteOverviewSection({
    super.key,
    required this.quote,
    required this.localePrefs,
  });

  final QuoteDocumentSnapshot quote;
  final LocalePreferencesState localePrefs;

  @override
  Widget build(BuildContext context) {
    return ProfessionalOverviewCard(
      title: 'Quote Overview',
      icon: Icons.request_quote_rounded,
      child: ProfessionalFieldGrid(
        fields: [
          ProfessionalFieldGridItem(
            label: 'Customer',
            value: quote.customerLabel,
          ),
          ProfessionalFieldGridItem(
            label: 'Quote Type',
            value: quote.transactionType,
          ),
          ProfessionalFieldGridItem(
            label: 'Status',
            value: quote.status,
          ),
          ProfessionalFieldGridItem(
            label: 'Quote Date',
            value: formatQuoteDate(
              context,
              localePrefs,
              quote.quoteDate,
              fallback: 'Not recorded',
            ),
          ),
          ProfessionalFieldGridItem(
            label: 'Valid Until',
            value: formatQuoteDate(
              context,
              localePrefs,
              quote.validUntil,
              fallback: 'Not set',
            ),
          ),
          if (quote.convertedSaleId != null)
            ProfessionalFieldGridItem(
              label: 'Converted Sale',
              value: 'Sale #${quote.convertedSaleId}',
            ),
        ],
      ),
    );
  }
}

class QuoteSummarySection extends StatelessWidget {
  const QuoteSummarySection({
    super.key,
    required this.quote,
    required this.isDesktop,
    this.footer,
  });

  final QuoteDocumentSnapshot quote;
  final bool isDesktop;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final totalQty = quote.items.fold<double>(
      0,
      (sum, item) => sum + ((item['quantity'] as num?)?.toDouble() ?? 0),
    );
    return ProfessionalSummaryCard(
      title: 'Commercial Summary',
      expandContent: isDesktop,
      rows: [
        (
          label: 'Item Count',
          value: quote.items.length.toString(),
          emphasize: false,
        ),
        (
          label: 'Total Qty',
          value: totalQty.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Subtotal',
          value: formatQuoteMoney(quote.subtotal),
          emphasize: false,
        ),
        (
          label: 'Tax',
          value: formatQuoteMoney(quote.taxAmount),
          emphasize: false,
        ),
        (
          label: 'Discount',
          value: formatQuoteMoney(quote.discountAmount),
          emphasize: false,
        ),
        (
          label: 'Quoted Total',
          value: formatQuoteMoney(quote.totalAmount),
          emphasize: true,
        ),
      ],
      footer: footer,
    );
  }
}

class QuoteItemsSection extends StatelessWidget {
  const QuoteItemsSection({
    super.key,
    required this.quote,
  });

  final QuoteDocumentSnapshot quote;

  @override
  Widget build(BuildContext context) {
    if (quote.items.isEmpty) {
      return const ProfessionalSectionCard(
        title: 'Quote Items',
        child: ProfessionalDocumentEmptyState(
          title: 'No quote items',
          message: 'This quote does not contain any active line items.',
          icon: Icons.inventory_2_outlined,
        ),
      );
    }

    return ProfessionalSectionCard(
      title: 'Quote Items',
      subtitle:
          'Review quantities, pricing, discount, and tax before sending or converting the quote.',
      child: Column(
        children: [
          for (final item in quote.items) ...[
            ProfessionalOverviewCard(
              title: _itemTitle(item),
              icon: Icons.inventory_2_rounded,
              child: ProfessionalFieldGrid(
                fields: [
                  ProfessionalFieldGridItem(
                    label: 'Quantity',
                    value: ((item['quantity'] as num?)?.toDouble() ?? 0)
                        .toStringAsFixed(2),
                  ),
                  ProfessionalFieldGridItem(
                    label: 'Unit Price',
                    value: formatQuoteMoney(
                      (item['unit_price'] as num?)?.toDouble() ?? 0,
                    ),
                  ),
                  ProfessionalFieldGridItem(
                    label: 'Discount %',
                    value:
                        ((item['discount_percentage'] as num?)?.toDouble() ?? 0)
                            .toStringAsFixed(2),
                  ),
                  ProfessionalFieldGridItem(
                    label: 'Tax',
                    value: formatQuoteMoney(
                      (item['tax_amount'] as num?)?.toDouble() ?? 0,
                    ),
                  ),
                  ProfessionalFieldGridItem(
                    label: 'Line Total',
                    value: formatQuoteMoney(
                      (item['line_total'] as num?)?.toDouble() ?? 0,
                    ),
                  ),
                ],
              ),
            ),
            if (item != quote.items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  String _itemTitle(Map<String, dynamic> item) {
    final productMap =
        item['product'] is Map<String, dynamic> ? item['product'] : null;
    final productName = item['product_name']?.toString().trim() ??
        productMap?['name']?.toString().trim() ??
        '';
    if (productName.isNotEmpty) return productName;
    final productId = item['product_id'];
    return productId == null ? 'Item' : 'Product #$productId';
  }
}

class QuoteNotesSection extends StatelessWidget {
  const QuoteNotesSection({
    super.key,
    required this.quote,
  });

  final QuoteDocumentSnapshot quote;

  @override
  Widget build(BuildContext context) {
    if (quote.notes.isEmpty) {
      return const SizedBox.shrink();
    }
    return ProfessionalSectionCard(
      title: 'Quote Notes',
      child: Text(quote.notes),
    );
  }
}

String formatQuoteMoney(double value) => value.toStringAsFixed(2);

String formatQuoteDate(
  BuildContext context,
  LocalePreferencesState localePrefs,
  DateTime? value, {
  String fallback = '',
}) {
  return AppDateTime.formatFlexibleDate(
    context,
    localePrefs,
    value?.toIso8601String(),
    fallback: fallback,
  );
}
