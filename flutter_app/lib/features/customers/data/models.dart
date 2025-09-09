class CustomerDto {
  final int customerId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final int paymentTerms; // days
  final double creditLimit;
  final bool isLoyalty;
  final int? loyaltyTierId;
  final bool isActive;
  final double creditBalance;

  CustomerDto({
    required this.customerId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    required this.paymentTerms,
    required this.creditLimit,
    required this.isLoyalty,
    required this.loyaltyTierId,
    required this.isActive,
    required this.creditBalance,
  });

  factory CustomerDto.fromJson(Map<String, dynamic> json) => CustomerDto(
        customerId: json['customer_id'] as int,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        taxNumber: json['tax_number'] as String?,
        paymentTerms: (json['payment_terms'] as num?)?.toInt() ?? 0,
        creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
        isLoyalty: json['is_loyalty'] as bool? ?? false,
        loyaltyTierId: json['loyalty_tier_id'] as int?,
        isActive: json['is_active'] as bool? ?? true,
        creditBalance: (json['credit_balance'] as num?)?.toDouble() ?? 0,
      );
}

class CustomerSummaryDto {
  final int customerId;
  final double totalSales;
  final double totalPayments;
  final double totalReturns;
  final double loyaltyPoints;

  CustomerSummaryDto({
    required this.customerId,
    required this.totalSales,
    required this.totalPayments,
    required this.totalReturns,
    required this.loyaltyPoints,
  });

  factory CustomerSummaryDto.fromJson(Map<String, dynamic> json) => CustomerSummaryDto(
        customerId: json['customer_id'] as int,
        totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0,
        totalPayments: (json['total_payments'] as num?)?.toDouble() ?? 0,
        totalReturns: (json['total_returns'] as num?)?.toDouble() ?? 0,
        loyaltyPoints: (json['loyalty_points'] as num?)?.toDouble() ?? 0,
      );
}

class CustomerCollectionDto {
  final int collectionId;
  final String collectionNumber;
  final double amount;
  final DateTime collectionDate;
  final String? paymentMethod;
  final String? referenceNumber;

  CustomerCollectionDto({
    required this.collectionId,
    required this.collectionNumber,
    required this.amount,
    required this.collectionDate,
    this.paymentMethod,
    this.referenceNumber,
  });

  factory CustomerCollectionDto.fromJson(Map<String, dynamic> json) => CustomerCollectionDto(
        collectionId: json['collection_id'] as int,
        collectionNumber: (json['collection_number'] ?? json['number'] ?? '').toString(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        collectionDate: DateTime.tryParse((json['collection_date'] ?? json['date'] ?? '').toString()) ?? DateTime.now(),
        paymentMethod: json['payment_method'] as String?,
        referenceNumber: json['reference_number'] as String?,
      );
}

