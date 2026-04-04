import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/shared/widgets/feature_menu.dart';
import 'package:ebs_lite/features/pos/presentation/pages/pos_page.dart';
import 'package:ebs_lite/features/pos/controllers/pos_notifier.dart';
import 'package:ebs_lite/features/promotions/presentation/pages/promotions_page.dart';
import 'package:ebs_lite/features/sales/presentation/pages/sales_history_page.dart';
import 'package:ebs_lite/features/sales/presentation/pages/sales_returns_page.dart';
import 'package:ebs_lite/features/sales/presentation/pages/invoices_page.dart';
import 'quotes_page.dart';

class SalesPage extends ConsumerWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      FeatureItem(
        icon: Icons.point_of_sale_rounded,
        label: 'New Sale',
        onTap: () {
          ref
              .read(posNotifierProvider.notifier)
              .startNewSaleSession(transactionType: 'RETAIL');
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PosPage()),
          );
        },
      ),
      FeatureItem(
        icon: Icons.receipt_long_rounded,
        label: 'B2B Invoices',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InvoicesPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.request_quote_rounded,
        label: 'Quotes',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QuotesPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.assignment_return_rounded,
        label: 'B2B Return',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SaleReturnFormPage(),
          ),
        ),
      ),
      FeatureItem(
        icon: Icons.undo_rounded,
        label: 'Refund Invoice',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SaleReturnFormPage(
              mode: SaleReturnDocumentMode.refundInvoice,
            ),
          ),
        ),
      ),
      FeatureItem(
        icon: Icons.history_rounded,
        label: 'Sale History',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SalesHistoryPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.percent_rounded,
        label: 'Promotions',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PromotionsPage()),
        ),
      ),
    ];

    return FeatureMenu(items: items, title: 'Sales');
  }
}
