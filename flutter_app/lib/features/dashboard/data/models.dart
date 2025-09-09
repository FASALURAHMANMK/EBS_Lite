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
    var todayPurchases =
        (json['today_purchases'] as num?)?.toDouble() ?? 0;

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
    if ((todayPurchases == 0) && (tPurchases != null)) todayPurchases = tPurchases;

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
    final collections = json['collections_today'] as int? ??
        json['collections'] as int? ?? 0;
    final expenses = json['expenses_today'] as int? ??
        json['payments_today'] as int? ?? json['expenses'] as int? ?? 0;

    return QuickActionCounts(
      sales: sales,
      purchases: purchases,
      collections: collections,
      expenses: expenses,
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
