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
  final int? settlementAccountId;
  final int? bankAccountId;
  final String reference;
  final String? description;
  final List<VoucherLineDto> lines;

  VoucherDto({
    required this.voucherId,
    required this.companyId,
    required this.type,
    required this.amount,
    required this.date,
    required this.accountId,
    required this.settlementAccountId,
    required this.bankAccountId,
    required this.reference,
    required this.description,
    required this.lines,
  });

  factory VoucherDto.fromJson(Map<String, dynamic> json) => VoucherDto(
        voucherId: _asInt(json['voucher_id']),
        companyId: _asInt(json['company_id']),
        type: (json['type'] ?? '').toString(),
        amount: _asDouble(json['amount']),
        date: _asDate(json['date']),
        accountId: _asInt(json['account_id']),
        settlementAccountId: _asNullableInt(json['settlement_account_id']),
        bankAccountId: _asNullableInt(json['bank_account_id']),
        reference: (json['reference'] ?? '').toString(),
        description: json['description']?.toString(),
        lines: (json['lines'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(VoucherLineDto.fromJson)
            .toList(),
      );
}

class VoucherLineDto {
  final int lineId;
  final int voucherId;
  final int companyId;
  final int accountId;
  final String? accountCode;
  final String? accountName;
  final int lineNo;
  final double debit;
  final double credit;
  final String? description;

  VoucherLineDto({
    required this.lineId,
    required this.voucherId,
    required this.companyId,
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.lineNo,
    required this.debit,
    required this.credit,
    required this.description,
  });

  factory VoucherLineDto.fromJson(Map<String, dynamic> json) => VoucherLineDto(
        lineId: _asInt(json['line_id']),
        voucherId: _asInt(json['voucher_id']),
        companyId: _asInt(json['company_id']),
        accountId: _asInt(json['account_id']),
        accountCode: json['account_code']?.toString(),
        accountName: json['account_name']?.toString(),
        lineNo: _asInt(json['line_no']),
        debit: _asDouble(json['debit']),
        credit: _asDouble(json['credit']),
        description: json['description']?.toString(),
      );
}

class VoucherLineInput {
  final int accountId;
  final double debit;
  final double credit;
  final String? description;

  const VoucherLineInput({
    required this.accountId,
    required this.debit,
    required this.credit,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'account_id': accountId,
        'debit': debit,
        'credit': credit,
        if ((description ?? '').trim().isNotEmpty)
          'description': description!.trim(),
      };
}

class ChartOfAccountDto {
  final int accountId;
  final int companyId;
  final String? accountCode;
  final String name;
  final String type;
  final String? subtype;
  final int? parentId;
  final String? parentCode;
  final String? parentName;
  final bool isActive;
  final double? currentBalance;

  ChartOfAccountDto({
    required this.accountId,
    required this.companyId,
    required this.accountCode,
    required this.name,
    required this.type,
    required this.subtype,
    required this.parentId,
    required this.parentCode,
    required this.parentName,
    required this.isActive,
    required this.currentBalance,
  });

  factory ChartOfAccountDto.fromJson(Map<String, dynamic> json) =>
      ChartOfAccountDto(
        accountId: _asInt(json['account_id']),
        companyId: _asInt(json['company_id']),
        accountCode: json['account_code']?.toString(),
        name: (json['name'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        subtype: json['subtype']?.toString(),
        parentId: _asNullableInt(json['parent_id']),
        parentCode: json['parent_code']?.toString(),
        parentName: json['parent_name']?.toString(),
        isActive: (json['is_active'] as bool?) ?? true,
        currentBalance: _asNullableDouble(json['current_balance']),
      );
}

class BankAccountDto {
  final int bankAccountId;
  final int companyId;
  final int ledgerAccountId;
  final String? ledgerAccountCode;
  final String? ledgerAccountName;
  final int? defaultLocationId;
  final String accountName;
  final String bankName;
  final String? accountNumberMasked;
  final String? branchName;
  final String? currencyCode;
  final String? statementImportHint;
  final double openingBalance;
  final bool isActive;
  final int unmatchedEntries;
  final int reviewEntries;
  final DateTime? lastStatementDate;

  BankAccountDto({
    required this.bankAccountId,
    required this.companyId,
    required this.ledgerAccountId,
    required this.ledgerAccountCode,
    required this.ledgerAccountName,
    required this.defaultLocationId,
    required this.accountName,
    required this.bankName,
    required this.accountNumberMasked,
    required this.branchName,
    required this.currencyCode,
    required this.statementImportHint,
    required this.openingBalance,
    required this.isActive,
    required this.unmatchedEntries,
    required this.reviewEntries,
    required this.lastStatementDate,
  });

  factory BankAccountDto.fromJson(Map<String, dynamic> json) => BankAccountDto(
        bankAccountId: _asInt(json['bank_account_id']),
        companyId: _asInt(json['company_id']),
        ledgerAccountId: _asInt(json['ledger_account_id']),
        ledgerAccountCode: json['ledger_account_code']?.toString(),
        ledgerAccountName: json['ledger_account_name']?.toString(),
        defaultLocationId: _asNullableInt(json['default_location_id']),
        accountName: (json['account_name'] ?? '').toString(),
        bankName: (json['bank_name'] ?? '').toString(),
        accountNumberMasked: json['account_number_masked']?.toString(),
        branchName: json['branch_name']?.toString(),
        currencyCode: json['currency_code']?.toString(),
        statementImportHint: json['statement_import_hint']?.toString(),
        openingBalance: _asDouble(json['opening_balance']),
        isActive: (json['is_active'] as bool?) ?? true,
        unmatchedEntries: _asInt(json['unmatched_entries']),
        reviewEntries: _asInt(json['review_entries']),
        lastStatementDate: _asNullableDate(json['last_statement_date']),
      );
}

class BankStatementMatchDto {
  final int matchId;
  final int companyId;
  final int bankAccountId;
  final int statementEntryId;
  final int ledgerEntryId;
  final double matchedAmount;
  final String matchKind;
  final String? notes;
  final int createdBy;
  final DateTime createdAt;
  final DateTime? ledgerDate;
  final String? ledgerReference;
  final String? ledgerDescription;

  BankStatementMatchDto({
    required this.matchId,
    required this.companyId,
    required this.bankAccountId,
    required this.statementEntryId,
    required this.ledgerEntryId,
    required this.matchedAmount,
    required this.matchKind,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.ledgerDate,
    required this.ledgerReference,
    required this.ledgerDescription,
  });

  factory BankStatementMatchDto.fromJson(Map<String, dynamic> json) =>
      BankStatementMatchDto(
        matchId: _asInt(json['match_id']),
        companyId: _asInt(json['company_id']),
        bankAccountId: _asInt(json['bank_account_id']),
        statementEntryId: _asInt(json['statement_entry_id']),
        ledgerEntryId: _asInt(json['ledger_entry_id']),
        matchedAmount: _asDouble(json['matched_amount']),
        matchKind: (json['match_kind'] ?? '').toString(),
        notes: json['notes']?.toString(),
        createdBy: _asInt(json['created_by']),
        createdAt: _asDate(json['created_at']),
        ledgerDate: _asNullableDate(json['ledger_date']),
        ledgerReference: json['ledger_reference']?.toString(),
        ledgerDescription: json['ledger_description']?.toString(),
      );
}

class BankStatementEntryDto {
  final int statementEntryId;
  final int companyId;
  final int bankAccountId;
  final DateTime entryDate;
  final DateTime? valueDate;
  final String? description;
  final String? reference;
  final String? externalRef;
  final String sourceType;
  final double depositAmount;
  final double withdrawalAmount;
  final double? runningBalance;
  final String status;
  final String? reviewReason;
  final double matchedAmount;
  final double availableAmount;
  final DateTime createdAt;
  final List<BankStatementMatchDto> matches;

  BankStatementEntryDto({
    required this.statementEntryId,
    required this.companyId,
    required this.bankAccountId,
    required this.entryDate,
    required this.valueDate,
    required this.description,
    required this.reference,
    required this.externalRef,
    required this.sourceType,
    required this.depositAmount,
    required this.withdrawalAmount,
    required this.runningBalance,
    required this.status,
    required this.reviewReason,
    required this.matchedAmount,
    required this.availableAmount,
    required this.createdAt,
    required this.matches,
  });

  factory BankStatementEntryDto.fromJson(Map<String, dynamic> json) =>
      BankStatementEntryDto(
        statementEntryId: _asInt(json['statement_entry_id']),
        companyId: _asInt(json['company_id']),
        bankAccountId: _asInt(json['bank_account_id']),
        entryDate: _asDate(json['entry_date']),
        valueDate: _asNullableDate(json['value_date']),
        description: json['description']?.toString(),
        reference: json['reference']?.toString(),
        externalRef: json['external_ref']?.toString(),
        sourceType: (json['source_type'] ?? '').toString(),
        depositAmount: _asDouble(json['deposit_amount']),
        withdrawalAmount: _asDouble(json['withdrawal_amount']),
        runningBalance: _asNullableDouble(json['running_balance']),
        status: (json['status'] ?? '').toString(),
        reviewReason: json['review_reason']?.toString(),
        matchedAmount: _asDouble(json['matched_amount']),
        availableAmount: _asDouble(json['available_amount']),
        createdAt: _asDate(json['created_at']),
        matches: (json['matches'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(BankStatementMatchDto.fromJson)
            .toList(),
      );
}

class AccountingPeriodDto {
  final int periodId;
  final int companyId;
  final String periodName;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final Map<String, dynamic> checklist;
  final String? notes;
  final DateTime? closedAt;
  final int? closedBy;
  final DateTime? reopenedAt;
  final int? reopenedBy;
  final DateTime createdAt;

  AccountingPeriodDto({
    required this.periodId,
    required this.companyId,
    required this.periodName,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.checklist,
    required this.notes,
    required this.closedAt,
    required this.closedBy,
    required this.reopenedAt,
    required this.reopenedBy,
    required this.createdAt,
  });

  factory AccountingPeriodDto.fromJson(Map<String, dynamic> json) =>
      AccountingPeriodDto(
        periodId: _asInt(json['period_id']),
        companyId: _asInt(json['company_id']),
        periodName: (json['period_name'] ?? '').toString(),
        startDate: _asDate(json['start_date']),
        endDate: _asDate(json['end_date']),
        status: (json['status'] ?? '').toString(),
        checklist: (json['checklist'] as Map<String, dynamic>? ??
            const <String, dynamic>{}),
        notes: json['notes']?.toString(),
        closedAt: _asNullableDate(json['closed_at']),
        closedBy: _asNullableInt(json['closed_by']),
        reopenedAt: _asNullableDate(json['reopened_at']),
        reopenedBy: _asNullableInt(json['reopened_by']),
        createdAt: _asDate(json['created_at']),
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

class FinanceIntegrityBucketDto {
  final String eventType;
  final String status;
  final int count;

  FinanceIntegrityBucketDto({
    required this.eventType,
    required this.status,
    required this.count,
  });

  factory FinanceIntegrityBucketDto.fromJson(Map<String, dynamic> json) =>
      FinanceIntegrityBucketDto(
        eventType: (json['event_type'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        count: _asInt(json['count']),
      );
}

class FinanceIntegritySummaryDto {
  final int pendingCount;
  final int processingCount;
  final int failedCount;
  final int completedCount;
  final List<FinanceIntegrityBucketDto> eventBuckets;

  FinanceIntegritySummaryDto({
    required this.pendingCount,
    required this.processingCount,
    required this.failedCount,
    required this.completedCount,
    required this.eventBuckets,
  });

  factory FinanceIntegritySummaryDto.fromJson(Map<String, dynamic> json) =>
      FinanceIntegritySummaryDto(
        pendingCount: _asInt(json['pending_count']),
        processingCount: _asInt(json['processing_count']),
        failedCount: _asInt(json['failed_count']),
        completedCount: _asInt(json['completed_count']),
        eventBuckets: (json['event_buckets'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FinanceIntegrityBucketDto.fromJson)
            .toList(),
      );
}

class FinanceOutboxEntryDto {
  final int outboxId;
  final String eventType;
  final String aggregateType;
  final int aggregateId;
  final String status;
  final int attemptCount;
  final String? lastError;
  final DateTime? lastAttemptAt;
  final DateTime nextAttemptAt;
  final DateTime? processedAt;
  final DateTime createdAt;

  FinanceOutboxEntryDto({
    required this.outboxId,
    required this.eventType,
    required this.aggregateType,
    required this.aggregateId,
    required this.status,
    required this.attemptCount,
    required this.lastError,
    required this.lastAttemptAt,
    required this.nextAttemptAt,
    required this.processedAt,
    required this.createdAt,
  });

  factory FinanceOutboxEntryDto.fromJson(Map<String, dynamic> json) =>
      FinanceOutboxEntryDto(
        outboxId: _asInt(json['outbox_id']),
        eventType: (json['event_type'] ?? '').toString(),
        aggregateType: (json['aggregate_type'] ?? '').toString(),
        aggregateId: _asInt(json['aggregate_id']),
        status: (json['status'] ?? '').toString(),
        attemptCount: _asInt(json['attempt_count']),
        lastError: json['last_error']?.toString(),
        lastAttemptAt: _asNullableDate(json['last_attempt_at']),
        nextAttemptAt: _asDate(json['next_attempt_at']),
        processedAt: _asNullableDate(json['processed_at']),
        createdAt: _asDate(json['created_at']),
      );
}

class FinanceLedgerMismatchDto {
  final String documentType;
  final int documentId;
  final String documentNumber;
  final int? locationId;
  final DateTime? documentDate;
  final double totalAmount;
  final String diagnostic;

  FinanceLedgerMismatchDto({
    required this.documentType,
    required this.documentId,
    required this.documentNumber,
    required this.locationId,
    required this.documentDate,
    required this.totalAmount,
    required this.diagnostic,
  });

  factory FinanceLedgerMismatchDto.fromJson(Map<String, dynamic> json) =>
      FinanceLedgerMismatchDto(
        documentType: (json['document_type'] ?? '').toString(),
        documentId: _asInt(json['document_id']),
        documentNumber: (json['document_number'] ?? '').toString(),
        locationId: _asNullableInt(json['location_id']),
        documentDate: _asNullableDate(json['document_date']),
        totalAmount: _asDouble(json['total_amount']),
        diagnostic: (json['diagnostic'] ?? '').toString(),
      );
}

class FinanceIntegrityDiagnosticsDto {
  final FinanceIntegritySummaryDto summary;
  final List<FinanceOutboxEntryDto> outboxEntries;
  final List<FinanceLedgerMismatchDto> missingLedgerEntries;

  FinanceIntegrityDiagnosticsDto({
    required this.summary,
    required this.outboxEntries,
    required this.missingLedgerEntries,
  });

  factory FinanceIntegrityDiagnosticsDto.fromJson(Map<String, dynamic> json) =>
      FinanceIntegrityDiagnosticsDto(
        summary: FinanceIntegritySummaryDto.fromJson(
          (json['summary'] as Map<String, dynamic>? ?? const {}),
        ),
        outboxEntries: (json['outbox_entries'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FinanceOutboxEntryDto.fromJson)
            .toList(),
        missingLedgerEntries:
            (json['missing_ledger_entries'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(FinanceLedgerMismatchDto.fromJson)
                .toList(),
      );
}

class FinanceReplayResultDto {
  final int processedCount;
  final int succeededCount;
  final int failedCount;

  FinanceReplayResultDto({
    required this.processedCount,
    required this.succeededCount,
    required this.failedCount,
  });

  factory FinanceReplayResultDto.fromJson(Map<String, dynamic> json) =>
      FinanceReplayResultDto(
        processedCount: _asInt(json['processed_count']),
        succeededCount: _asInt(json['succeeded_count']),
        failedCount: _asInt(json['failed_count']),
      );
}

class FinanceRepairLedgerResultDto {
  final int enqueuedCount;
  final int processedCount;
  final int failedCount;

  FinanceRepairLedgerResultDto({
    required this.enqueuedCount,
    required this.processedCount,
    required this.failedCount,
  });

  factory FinanceRepairLedgerResultDto.fromJson(Map<String, dynamic> json) =>
      FinanceRepairLedgerResultDto(
        enqueuedCount: _asInt(json['enqueued_count']),
        processedCount: _asInt(json['processed_count']),
        failedCount: _asInt(json['failed_count']),
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
