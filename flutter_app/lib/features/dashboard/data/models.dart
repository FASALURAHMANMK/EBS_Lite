class DashboardMetrics {
  final double creditOutstanding;
  final double inventoryValue;
  final double todaySales;
  final double dailyCashSummary;

  DashboardMetrics({
    required this.creditOutstanding,
    required this.inventoryValue,
    required this.todaySales,
    required this.dailyCashSummary,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) => DashboardMetrics(
        creditOutstanding: (json['credit_outstanding'] as num?)?.toDouble() ?? 0,
        inventoryValue: (json['inventory_value'] as num?)?.toDouble() ?? 0,
        todaySales: (json['today_sales'] as num?)?.toDouble() ?? 0,
        dailyCashSummary: (json['daily_cash_summary'] as num?)?.toDouble() ?? 0,
      );
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

  factory QuickActionCounts.fromJson(Map<String, dynamic> json) => QuickActionCounts(
        sales: json['sales'] as int? ?? 0,
        purchases: json['purchases'] as int? ?? 0,
        collections: json['collections'] as int? ?? 0,
        expenses: json['expenses'] as int? ?? 0,
      );
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
