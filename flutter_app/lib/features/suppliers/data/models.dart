class SupplierDto {
  final int supplierId;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final int paymentTerms; // days
  final double creditLimit;
  final bool isActive;
  final double totalPurchases;
  final double totalReturns;
  final double outstandingAmount;
  final DateTime? lastPurchaseDate;

  SupplierDto({
    required this.supplierId,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    required this.paymentTerms,
    required this.creditLimit,
    required this.isActive,
    required this.totalPurchases,
    required this.totalReturns,
    required this.outstandingAmount,
    this.lastPurchaseDate,
  });

  factory SupplierDto.fromJson(Map<String, dynamic> json) => SupplierDto(
        supplierId: json['supplier_id'] as int,
        name: json['name'] as String? ?? '',
        contactPerson: json['contact_person'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        paymentTerms: json['payment_terms'] as int? ?? 0,
        creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
        totalPurchases: (json['total_purchases'] as num?)?.toDouble() ?? 0,
        totalReturns: (json['total_returns'] as num?)?.toDouble() ?? 0,
        outstandingAmount: (json['outstanding_amount'] as num?)?.toDouble() ?? 0,
        lastPurchaseDate: json['last_purchase_date'] != null
            ? DateTime.tryParse(json['last_purchase_date'] as String)
            : null,
      );
}

class SupplierSummaryDto {
  final int supplierId;
  final double totalPurchases;
  final double totalPayments;
  final double totalReturns;
  final double outstandingBalance;

  SupplierSummaryDto({
    required this.supplierId,
    required this.totalPurchases,
    required this.totalPayments,
    required this.totalReturns,
    required this.outstandingBalance,
  });

  factory SupplierSummaryDto.fromJson(Map<String, dynamic> json) => SupplierSummaryDto(
        supplierId: json['supplier_id'] as int,
        totalPurchases: (json['total_purchases'] as num?)?.toDouble() ?? 0,
        totalPayments: (json['total_payments'] as num?)?.toDouble() ?? 0,
        totalReturns: (json['total_returns'] as num?)?.toDouble() ?? 0,
        outstandingBalance: (json['outstanding_balance'] as num?)?.toDouble() ?? 0,
      );
}

class SupplierPaymentDto {
  final int paymentId;
  final String paymentNumber;
  final double amount;
  final DateTime paymentDate;
  final String? referenceNumber;

  SupplierPaymentDto({
    required this.paymentId,
    required this.paymentNumber,
    required this.amount,
    required this.paymentDate,
    this.referenceNumber,
  });

  factory SupplierPaymentDto.fromJson(Map<String, dynamic> json) => SupplierPaymentDto(
        paymentId: json['payment_id'] as int,
        paymentNumber: json['payment_number'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        paymentDate: DateTime.tryParse(json['payment_date'] as String? ?? '') ?? DateTime.now(),
        referenceNumber: json['reference_number'] as String?,
      );
}

