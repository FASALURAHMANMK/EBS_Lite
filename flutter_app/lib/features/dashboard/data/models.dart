class DashboardMetrics {
  final double creditOutstanding;
  final double inventoryValue;
  final double todaySales;
  final double todayPurchases;
  final double dailyCashSummary;
  final double? totalSales; // optional fallback support
  final double? totalPurchases;
  final double? cashInTotal;
  final double? cashOutTotal;

  DashboardMetrics({
    required this.creditOutstanding,
    required this.inventoryValue,
    required this.todaySales,
    required this.todayPurchases,
    required this.dailyCashSummary,
    this.totalSales,
    this.totalPurchases,
    this.cashInTotal,
    this.cashOutTotal,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    final creditOutstanding =
        (json['credit_outstanding'] as num?)?.toDouble() ?? 0;
    final inventoryValue = (json['inventory_value'] as num?)?.toDouble() ?? 0;
    var todaySales = (json['today_sales'] as num?)?.toDouble() ?? 0;
    var todayPurchases = (json['today_purchases'] as num?)?.toDouble() ?? 0;

    // Backend exposes cash_in and cash_out. If daily_cash_summary is not
    // present, compute it as (cash_in - cash_out).
    final dailyCash = (json['daily_cash_summary'] as num?)?.toDouble();
    final cashIn = (json['cash_in'] as num?)?.toDouble();
    final cashOut = (json['cash_out'] as num?)?.toDouble();
    var dailyCashSummary = dailyCash ??
        ((cashIn != null && cashOut != null) ? (cashIn - cashOut) : 0);

    // Optional totals for non-daily fallback
    final tSales = (json['total_sales'] as num?)?.toDouble();
    final tPurchases = (json['total_purchases'] as num?)?.toDouble();
    final tCashIn = (json['cash_in_total'] as num?)?.toDouble();
    final tCashOut = (json['cash_out_total'] as num?)?.toDouble();

    // If today's values are zero and totals exist, use totals as a fallback so the dashboard isn't empty
    if ((todaySales == 0) && (tSales != null)) todaySales = tSales;
    if ((todayPurchases == 0) && (tPurchases != null)) {
      todayPurchases = tPurchases;
    }

    // Fallback cash summary using totals if daily is zero
    if (dailyCashSummary == 0 && tCashIn != null && tCashOut != null) {
      dailyCashSummary = tCashIn - tCashOut;
    }

    return DashboardMetrics(
      creditOutstanding: creditOutstanding,
      inventoryValue: inventoryValue,
      todaySales: todaySales,
      todayPurchases: todayPurchases,
      dailyCashSummary: dailyCashSummary,
      totalSales: tSales,
      totalPurchases: tPurchases,
      cashInTotal: tCashIn,
      cashOutTotal: tCashOut,
    );
  }
}

class QuickActionCounts {
  final int sales;
  final int purchases;
  final int collections;
  final int expenses;

  QuickActionCounts({
    required this.sales,
    required this.purchases,
    required this.collections,
    required this.expenses,
  });

  factory QuickActionCounts.fromJson(Map<String, dynamic> json) {
    // Map from backend fields: sales_today, purchases_today, collections_today,
    // Prefer expenses_today; fallback to payments_today for legacy support.
    final sales = json['sales_today'] as int? ?? json['sales'] as int? ?? 0;
    final purchases =
        json['purchases_today'] as int? ?? json['purchases'] as int? ?? 0;
    final collections =
        json['collections_today'] as int? ?? json['collections'] as int? ?? 0;
    final expenses = json['expenses_today'] as int? ??
        json['payments_today'] as int? ??
        json['expenses'] as int? ??
        0;

    return QuickActionCounts(
      sales: sales,
      purchases: purchases,
      collections: collections,
      expenses: expenses,
    );
  }
}

class DashboardOverview {
  final DashboardMetrics metrics;
  final QuickActionCounts quickActions;
  final List<DashboardCashFlowTransaction> recentTransactions;
  final List<DashboardLowStockItem> lowStockItems;

  DashboardOverview({
    required this.metrics,
    required this.quickActions,
    required this.recentTransactions,
    required this.lowStockItems,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    return DashboardOverview(
      metrics: DashboardMetrics.fromJson(
        (json['metrics'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      quickActions: QuickActionCounts.fromJson(
        (json['quick_actions'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      recentTransactions: ((json['recent_transactions'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => DashboardCashFlowTransaction.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
      lowStockItems: ((json['low_stock_items'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => DashboardLowStockItem.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class DashboardCashFlowTransaction {
  final String id;
  final String transactionType;
  final String entityName;
  final String? referenceNumber;
  final double amount;
  final String flowDirection;
  final String status;
  final DateTime? occurredAt;

  DashboardCashFlowTransaction({
    required this.id,
    required this.transactionType,
    required this.entityName,
    required this.referenceNumber,
    required this.amount,
    required this.flowDirection,
    required this.status,
    required this.occurredAt,
  });

  factory DashboardCashFlowTransaction.fromJson(Map<String, dynamic> json) {
    final occurredAtRaw = json['occurred_at']?.toString();
    return DashboardCashFlowTransaction(
      id: json['id']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? '',
      entityName: json['entity_name']?.toString() ?? '',
      referenceNumber: json['reference_number']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      flowDirection: json['flow_direction']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      occurredAt:
          occurredAtRaw == null ? null : DateTime.tryParse(occurredAtRaw),
    );
  }
}

class DashboardLowStockItem {
  final int productId;
  final String productName;
  final String locationName;
  final double currentStock;
  final int reorderLevel;
  final String severity;

  DashboardLowStockItem({
    required this.productId,
    required this.productName,
    required this.locationName,
    required this.currentStock,
    required this.reorderLevel,
    required this.severity,
  });

  factory DashboardLowStockItem.fromJson(Map<String, dynamic> json) {
    return DashboardLowStockItem(
      productId: json['product_id'] as int? ?? 0,
      productName: json['product_name']?.toString() ?? '',
      locationName: json['location_name']?.toString() ?? '',
      currentStock: (json['current_stock'] as num?)?.toDouble() ?? 0,
      reorderLevel: json['reorder_level'] as int? ?? 0,
      severity: json['severity']?.toString() ?? 'LOW',
    );
  }
}

class Location {
  final int locationId;
  final String name;

  Location({required this.locationId, required this.name});

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        locationId: json['location_id'] as int,
        name: json['name'] as String? ?? '',
      );
}
