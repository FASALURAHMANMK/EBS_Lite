import 'package:flutter/material.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/professional_document_widgets.dart';
import 'sales_workbench_widgets.dart';

class SaleReturnDocumentSnapshot {
  const SaleReturnDocumentSnapshot(this.raw);

  final Map<String, dynamic> raw;

  int? get returnId => (raw['return_id'] as num?)?.toInt();
  int? get saleId => (raw['sale_id'] as num?)?.toInt();
  int? get customerId => (raw['customer_id'] as num?)?.toInt();
  int? get locationId => (raw['location_id'] as num?)?.toInt();
  int? get createdBy => (raw['created_by'] as num?)?.toInt();
  String get number => raw['return_number']?.toString().trim() ?? '';
  String get transactionType =>
      (raw['transaction_type']?.toString() ?? 'B2B').trim();
  String get status => (raw['status']?.toString() ?? 'COMPLETED').trim();
  String get reason => raw['reason']?.toString().trim() ?? '';
  double get totalAmount => (raw['total_amount'] as num?)?.toDouble() ?? 0;
  DateTime? get returnDate =>
      DateTime.tryParse(raw['return_date']?.toString() ?? '');
  DateTime? get createdAt =>
      DateTime.tryParse(raw['created_at']?.toString() ?? '');
  String get locationName => raw['location_name']?.toString().trim() ?? '';
  String get createdByName => raw['created_by_name']?.toString().trim() ?? '';
  Map<String, dynamic>? get sale =>
      raw['sale'] is Map<String, dynamic> ? raw['sale'] : null;
  Map<String, dynamic>? get customer =>
      raw['customer'] is Map<String, dynamic> ? raw['customer'] : null;
  List<Map<String, dynamic>> get items =>
      (raw['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();

  bool get hasSourceSale => saleId != null || sourceSaleNumber.isNotEmpty;

  String get title => number.isEmpty
      ? (returnId == null ? 'Sale Return' : 'Return #$returnId')
      : number;

  String get sourceSaleNumber => sale?['sale_number']?.toString().trim() ?? '';

  String get sourceSaleLabel {
    if (sourceSaleNumber.isNotEmpty) {
      return sourceSaleNumber;
    }
    return saleId == null ? 'Not linked' : 'Sale #$saleId';
  }

  String get customerLabel {
    final nested = customer?['name']?.toString().trim() ?? '';
    if (nested.isNotEmpty) {
      return nested;
    }
    if (customerId != null) {
      return 'Customer #$customerId';
    }
    return transactionType.trim().toUpperCase() == 'RETAIL'
        ? 'Retail return'
        : 'B2B return';
  }

  String get locationLabel {
    if (locationName.isNotEmpty) {
      return locationName;
    }
    return locationId == null ? 'Not available' : 'Location #$locationId';
  }

  String get createdByLabel {
    if (createdByName.isNotEmpty) {
      return createdByName;
    }
    return createdBy == null ? 'Not available' : 'User #$createdBy';
  }

  String get reasonLabel => reason.isEmpty ? 'No reason recorded' : reason;

  double get totalQuantity => items.fold<double>(
        0,
        (sum, item) => sum + ((item['quantity'] as num?)?.toDouble() ?? 0),
      );
}

class SaleReturnDocumentHeaderCard extends StatelessWidget {
  const SaleReturnDocumentHeaderCard({
    super.key,
    required this.document,
  });

  final SaleReturnDocumentSnapshot document;

  @override
  Widget build(BuildContext context) {
    return ProfessionalDocumentHeader(
      title: document.title,
      subtitle:
          'Review the source invoice, customer, return reason, and returned lines from the same denser Sales detail shell used by the stronger invoice and quote flows.',
      badges: [
        SalesTransactionTypeChip(transactionType: document.transactionType),
        SalesStatusChip(status: document.status),
        const ProfessionalBadge(
          label: 'Sale Return',
          backgroundColor: Color(0xFFEAF1F8),
          foregroundColor: Color(0xFF23415F),
        ),
        if (document.hasSourceSale)
          const ProfessionalBadge(
            label: 'Source Linked',
            backgroundColor: Color(0xFFE8F3EC),
            foregroundColor: Color(0xFF255C35),
          ),
      ],
    );
  }
}

class SaleReturnOverviewSection extends StatelessWidget {
  const SaleReturnOverviewSection({
    super.key,
    required this.document,
    required this.localePrefs,
  });

  final SaleReturnDocumentSnapshot document;
  final LocalePreferencesState localePrefs;

  @override
  Widget build(BuildContext context) {
    return ProfessionalOverviewCard(
      title: 'Return Overview',
      icon: Icons.assignment_return_rounded,
      child: ProfessionalFieldGrid(
        fields: [
          ProfessionalFieldGridItem(
            label: 'Customer',
            value: document.customerLabel,
          ),
          ProfessionalFieldGridItem(
            label: 'Source Invoice',
            value: document.sourceSaleLabel,
          ),
          ProfessionalFieldGridItem(
            label: 'Return Date',
            value: formatSaleReturnDate(
              context,
              localePrefs,
              document.returnDate,
              fallback: 'Not available',
            ),
          ),
          ProfessionalFieldGridItem(
            label: 'Location',
            value: document.locationLabel,
          ),
          ProfessionalFieldGridItem(
            label: 'Created By',
            value: document.createdByLabel,
          ),
          ProfessionalFieldGridItem(
            label: 'Recorded At',
            value: formatSaleReturnDate(
              context,
              localePrefs,
              document.createdAt,
              fallback: 'Not recorded',
            ),
          ),
        ],
      ),
    );
  }
}

class SaleReturnSummarySection extends StatelessWidget {
  const SaleReturnSummarySection({
    super.key,
    required this.document,
    required this.isDesktop,
    this.footer,
  });

  final SaleReturnDocumentSnapshot document;
  final bool isDesktop;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return ProfessionalSummaryCard(
      title: 'Return Summary',
      expandContent: isDesktop,
      rows: [
        (
          label: 'Item Count',
          value: document.items.length.toString(),
          emphasize: false,
        ),
        (
          label: 'Total Qty',
          value: document.totalQuantity.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Document Status',
          value: document.status,
          emphasize: false,
        ),
        (
          label: 'Returned Amount',
          value: formatSaleReturnMoney(document.totalAmount),
          emphasize: true,
        ),
      ],
      footer: footer,
    );
  }
}

class SaleReturnItemsSection extends StatelessWidget {
  const SaleReturnItemsSection({
    super.key,
    required this.document,
  });

  final SaleReturnDocumentSnapshot document;

  @override
  Widget build(BuildContext context) {
    if (document.items.isEmpty) {
      return const ProfessionalSectionCard(
        title: 'Returned Items',
        child: ProfessionalDocumentEmptyState(
          title: 'No returned items',
          message: 'This return does not contain any line items.',
          icon: Icons.inventory_2_outlined,
        ),
      );
    }

    return ProfessionalSectionCard(
      title: 'Returned Items',
      subtitle:
          'Review quantities, pricing, and source-line references before reconciling the return against the original invoice.',
      child: Column(
        children: [
          for (final item in document.items) ...[
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
                    value: formatSaleReturnMoney(
                      (item['unit_price'] as num?)?.toDouble() ?? 0,
                    ),
                  ),
                  ProfessionalFieldGridItem(
                    label: 'Line Total',
                    value: formatSaleReturnMoney(
                      ((item['line_total'] as num?)?.toDouble()) ??
                          (((item['quantity'] as num?)?.toDouble() ?? 0) *
                              ((item['unit_price'] as num?)?.toDouble() ?? 0)),
                    ),
                  ),
                  if ((item['sale_detail_id'] as num?)?.toInt() != null)
                    ProfessionalFieldGridItem(
                      label: 'Source Line',
                      value:
                          'Sale line #${(item['sale_detail_id'] as num).toInt()}',
                    ),
                ],
              ),
            ),
            if (item != document.items.last) const SizedBox(height: 10),
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
    if (productName.isNotEmpty) {
      return productName;
    }
    final productId = (item['product_id'] as num?)?.toInt();
    return productId == null ? 'Item' : 'Product #$productId';
  }
}

class SaleReturnReasonSection extends StatelessWidget {
  const SaleReturnReasonSection({
    super.key,
    required this.document,
  });

  final SaleReturnDocumentSnapshot document;

  @override
  Widget build(BuildContext context) {
    return ProfessionalSectionCard(
      title: 'Return Reason',
      child: Text(document.reasonLabel),
    );
  }
}

String formatSaleReturnMoney(double value) => value.toStringAsFixed(2);

String formatSaleReturnDate(
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
