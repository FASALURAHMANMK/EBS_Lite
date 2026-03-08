import 'dart:convert';

class CashRegisterDto {
  final int registerId;
  final int locationId;
  final DateTime date;
  final double openingBalance;
  final double? closingBalance;
  final double expectedBalance;
  final double cashIn;
  final double cashOut;
  final double variance;
  final int? openedBy;
  final int? closedBy;
  final String status;
  final bool trainingMode;

  CashRegisterDto({
    required this.registerId,
    required this.locationId,
    required this.date,
    required this.openingBalance,
    required this.closingBalance,
    required this.expectedBalance,
    required this.cashIn,
    required this.cashOut,
    required this.variance,
    required this.openedBy,
    required this.closedBy,
    required this.status,
    required this.trainingMode,
  });

  factory CashRegisterDto.fromJson(Map<String, dynamic> json) {
    return CashRegisterDto(
      registerId: _asInt(json['register_id']),
      locationId: _asInt(json['location_id']),
      date: _asDate(json['date']),
      openingBalance: _asDouble(json['opening_balance']),
      closingBalance: _asNullableDouble(json['closing_balance']),
      expectedBalance: _asDouble(json['expected_balance']),
      cashIn: _asDouble(json['cash_in']),
      cashOut: _asDouble(json['cash_out']),
      variance: _asDouble(json['variance']),
      openedBy: _asNullableInt(json['opened_by']),
      closedBy: _asNullableInt(json['closed_by']),
      status: (json['status'] ?? '').toString(),
      trainingMode: (json['training_mode'] as bool?) ?? false,
    );
  }
}

class VoucherDto {
  final int voucherId;
  final int companyId;
  final String type;
  final double amount;
  final DateTime date;
  final int accountId;
  final String reference;
  final String? description;

  VoucherDto({
    required this.voucherId,
    required this.companyId,
    required this.type,
    required this.amount,
    required this.date,
    required this.accountId,
    required this.reference,
    required this.description,
  });

  factory VoucherDto.fromJson(Map<String, dynamic> json) => VoucherDto(
        voucherId: _asInt(json['voucher_id']),
        companyId: _asInt(json['company_id']),
        type: (json['type'] ?? '').toString(),
        amount: _asDouble(json['amount']),
        date: _asDate(json['date']),
        accountId: _asInt(json['account_id']),
        reference: (json['reference'] ?? '').toString(),
        description: json['description']?.toString(),
      );
}

class LedgerBalanceDto {
  final int accountId;
  final String? accountCode;
  final String? accountName;
  final String? accountType;
  final double balance;

  LedgerBalanceDto({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.balance,
  });

  factory LedgerBalanceDto.fromJson(Map<String, dynamic> json) =>
      LedgerBalanceDto(
        accountId: _asInt(json['account_id']),
        accountCode: json['account_code']?.toString(),
        accountName: json['account_name']?.toString(),
        accountType: json['account_type']?.toString(),
        balance: _asDouble(json['balance']),
      );
}

class VoucherSummaryDto {
  final int voucherId;
  final String type;
  final double amount;
  final String reference;
  final String? description;

  VoucherSummaryDto({
    required this.voucherId,
    required this.type,
    required this.amount,
    required this.reference,
    required this.description,
  });

  factory VoucherSummaryDto.fromJson(Map<String, dynamic> json) =>
      VoucherSummaryDto(
        voucherId: _asInt(json['voucher_id']),
        type: (json['type'] ?? '').toString(),
        amount: _asDouble(json['amount']),
        reference: (json['reference'] ?? '').toString(),
        description: json['description']?.toString(),
      );
}

class SaleSummaryDto {
  final int saleId;
  final String saleNumber;
  final double totalAmount;
  final DateTime? saleDate;

  SaleSummaryDto({
    required this.saleId,
    required this.saleNumber,
    required this.totalAmount,
    required this.saleDate,
  });

  factory SaleSummaryDto.fromJson(Map<String, dynamic> json) => SaleSummaryDto(
        saleId: _asInt(json['sale_id']),
        saleNumber: (json['sale_number'] ?? '').toString(),
        totalAmount: _asDouble(json['total_amount']),
        saleDate: _asNullableDate(json['sale_date']),
      );
}

class PurchaseSummaryDto {
  final int purchaseId;
  final String purchaseNumber;
  final double totalAmount;
  final DateTime? purchaseDate;

  PurchaseSummaryDto({
    required this.purchaseId,
    required this.purchaseNumber,
    required this.totalAmount,
    required this.purchaseDate,
  });

  factory PurchaseSummaryDto.fromJson(Map<String, dynamic> json) =>
      PurchaseSummaryDto(
        purchaseId: _asInt(json['purchase_id']),
        purchaseNumber: (json['purchase_number'] ?? '').toString(),
        totalAmount: _asDouble(json['total_amount']),
        purchaseDate: _asNullableDate(json['purchase_date']),
      );
}

class LedgerEntryDto {
  final int entryId;
  final int accountId;
  final DateTime date;
  final double debit;
  final double credit;
  final double balance;
  final String? transactionType;
  final int? transactionId;
  final String? description;
  final VoucherSummaryDto? voucher;
  final SaleSummaryDto? sale;
  final PurchaseSummaryDto? purchase;

  LedgerEntryDto({
    required this.entryId,
    required this.accountId,
    required this.date,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.transactionType,
    required this.transactionId,
    required this.description,
    required this.voucher,
    required this.sale,
    required this.purchase,
  });

  factory LedgerEntryDto.fromJson(Map<String, dynamic> json) => LedgerEntryDto(
        entryId: _asInt(json['entry_id']),
        accountId: _asInt(json['account_id']),
        date: _asDate(json['date']),
        debit: _asDouble(json['debit']),
        credit: _asDouble(json['credit']),
        balance: _asDouble(json['balance']),
        transactionType: json['transaction_type']?.toString(),
        transactionId: _asNullableInt(json['transaction_id']),
        description: json['description']?.toString(),
        voucher: (json['voucher'] is Map<String, dynamic>)
            ? VoucherSummaryDto.fromJson(
                json['voucher'] as Map<String, dynamic>)
            : null,
        sale: (json['sale'] is Map<String, dynamic>)
            ? SaleSummaryDto.fromJson(json['sale'] as Map<String, dynamic>)
            : null,
        purchase: (json['purchase'] is Map<String, dynamic>)
            ? PurchaseSummaryDto.fromJson(
                json['purchase'] as Map<String, dynamic>)
            : null,
      );
}

class AuditLogDto {
  final int logId;
  final int? userId;
  final String action;
  final String tableName;
  final int? recordId;
  final dynamic oldValue;
  final dynamic newValue;
  final dynamic fieldChanges;
  final String? ipAddress;
  final String? userAgent;
  final DateTime timestamp;

  AuditLogDto({
    required this.logId,
    required this.userId,
    required this.action,
    required this.tableName,
    required this.recordId,
    required this.oldValue,
    required this.newValue,
    required this.fieldChanges,
    required this.ipAddress,
    required this.userAgent,
    required this.timestamp,
  });

  factory AuditLogDto.fromJson(Map<String, dynamic> json) => AuditLogDto(
        logId: _asInt(json['log_id']),
        userId: _asNullableInt(json['user_id']),
        action: (json['action'] ?? '').toString(),
        tableName: (json['table_name'] ?? '').toString(),
        recordId: _asNullableInt(json['record_id']),
        oldValue: _decodeJson(json['old_value']),
        newValue: _decodeJson(json['new_value']),
        fieldChanges: _decodeJson(json['field_changes']),
        ipAddress: json['ip_address']?.toString(),
        userAgent: json['user_agent']?.toString(),
        timestamp: _asDate(json['timestamp']),
      );
}

class PaginatedResult<T> {
  final List<T> items;
  final MetaDto? meta;

  const PaginatedResult({required this.items, required this.meta});
}

class MetaDto {
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  MetaDto({
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  factory MetaDto.fromJson(Map<String, dynamic> json) => MetaDto(
        page: _asInt(json['page']),
        perPage: _asInt(json['per_page']),
        total: _asInt(json['total']),
        totalPages: _asInt(json['total_pages']),
      );
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

int? _asNullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

double? _asNullableDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

DateTime _asDate(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) {
    return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _asNullableDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

dynamic _decodeJson(dynamic v) {
  if (v == null) return null;
  if (v is Map || v is List) return v;
  if (v is String) {
    final trimmed = v.trim();
    if (trimmed.isEmpty) return v;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return v;
    }
  }
  return v;
}
