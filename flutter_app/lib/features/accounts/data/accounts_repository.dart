import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../features/dashboard/controllers/location_notifier.dart';
import 'models.dart';

class AccountsRepository {
  AccountsRepository(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;

  int? get _locationId =>
      _ref.read(locationNotifierProvider).selected?.locationId;

  Future<List<CashRegisterDto>> getCashRegisters({int? locationId}) async {
    final loc = locationId ?? _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/cash-registers',
        queryParameters: qp.isEmpty ? null : qp);
    final list = _extractList(res);
    return list.map((e) => CashRegisterDto.fromJson(e)).toList();
  }

  Future<int> openCashRegister({
    required double openingBalance,
    int? locationId,
  }) async {
    final loc = locationId ?? _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.post(
      '/cash-registers/open',
      data: {'opening_balance': openingBalance},
      queryParameters: qp.isEmpty ? null : qp,
    );
    final data = _extractMap(res);
    return (data['register_id'] as int?) ?? 0;
  }

  Future<void> closeCashRegister({
    required double closingBalance,
    Map<String, int>? denominations,
    int? locationId,
  }) async {
    final loc = locationId ?? _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    await _dio.post(
      '/cash-registers/close',
      data: {
        'closing_balance': closingBalance,
        if (denominations != null && denominations.isNotEmpty)
          'denominations': denominations,
      },
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  Future<void> recordCashTally({
    required double count,
    String? notes,
    Map<String, int>? denominations,
    int? locationId,
  }) async {
    final loc = locationId ?? _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    await _dio.post(
      '/cash-registers/tally',
      data: {
        'count': count,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (denominations != null && denominations.isNotEmpty)
          'denominations': denominations,
      },
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  Future<int> recordCashMovement({
    required String direction, // IN | OUT
    required double amount,
    required String reasonCode,
    String? notes,
    int? locationId,
  }) async {
    final loc = locationId ?? _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.post(
      '/cash-registers/movement',
      data: {
        'direction': direction,
        'amount': amount,
        'reason_code': reasonCode.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
      queryParameters: qp.isEmpty ? null : qp,
    );
    final data = _extractMap(res);
    return (data['event_id'] as int?) ?? 0;
  }

  Future<void> forceCloseCashRegister({
    required String reason,
    double? closingBalance,
    Map<String, int>? denominations,
    int? locationId,
  }) async {
    final loc = locationId ?? _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    await _dio.post(
      '/cash-registers/force-close',
      data: {
        'reason': reason.trim(),
        if (closingBalance != null) 'closing_balance': closingBalance,
        if (denominations != null && denominations.isNotEmpty)
          'denominations': denominations,
      },
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  Future<void> enableTrainingMode({int? locationId}) async {
    final loc = locationId ?? _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    await _dio.post(
      '/cash-registers/training/enable',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  Future<void> disableTrainingMode({int? locationId}) async {
    final loc = locationId ?? _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    await _dio.post(
      '/cash-registers/training/disable',
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  Future<PaginatedResult<VoucherDto>> getVouchers({
    String? type,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    final qp = <String, dynamic>{
      if (type != null && type.isNotEmpty) 'type': type,
      if (dateFrom != null) 'date_from': dateFrom.toIso8601String(),
      if (dateTo != null) 'date_to': dateTo.toIso8601String(),
      'page': page,
      'per_page': perPage,
    };
    final res = await _dio.get('/vouchers', queryParameters: qp);
    return _extractPaginated(res, VoucherDto.fromJson);
  }

  Future<int> createVoucher({
    required String type,
    int? accountId,
    double? amount,
    required String reference,
    int? settlementAccountId,
    int? bankAccountId,
    DateTime? date,
    List<VoucherLineInput> lines = const [],
    String? description,
    String? idempotencyKey,
  }) async {
    final idem = (idempotencyKey ?? '').trim();
    final res = await _dio.post(
      '/vouchers/$type',
      data: {
        if (accountId != null) 'account_id': accountId,
        if (amount != null) 'amount': amount,
        if (settlementAccountId != null)
          'settlement_account_id': settlementAccountId,
        if (bankAccountId != null) 'bank_account_id': bankAccountId,
        'reference': reference.trim(),
        if (date != null) 'date': date.toIso8601String(),
        if (lines.isNotEmpty) 'lines': lines.map((e) => e.toJson()).toList(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
      options: Options(
        headers: {
          if (idem.isNotEmpty) 'Idempotency-Key': idem,
          if (idem.isNotEmpty) 'X-Idempotency-Key': idem,
        },
      ),
    );
    final data = _extractMap(res);
    return (data['voucher_id'] as int?) ?? 0;
  }

  Future<List<ChartOfAccountDto>> getChartOfAccounts({
    bool includeInactive = false,
  }) async {
    final res = await _dio.get(
      '/chart-of-accounts',
      queryParameters: {
        if (includeInactive) 'include_inactive': true,
      },
    );
    final list = _extractList(res);
    return list.map((e) => ChartOfAccountDto.fromJson(e)).toList();
  }

  Future<void> createChartOfAccount({
    String? accountCode,
    required String name,
    required String type,
    String? subtype,
    int? parentId,
    bool isActive = true,
  }) async {
    await _dio.post(
      '/chart-of-accounts',
      data: {
        if ((accountCode ?? '').trim().isNotEmpty)
          'account_code': accountCode!.trim(),
        'name': name.trim(),
        'type': type.trim(),
        if ((subtype ?? '').trim().isNotEmpty) 'subtype': subtype!.trim(),
        if (parentId != null) 'parent_id': parentId,
        'is_active': isActive,
      },
    );
  }

  Future<void> updateChartOfAccount({
    required int accountId,
    String? accountCode,
    String? name,
    String? type,
    String? subtype,
    int? parentId,
    bool? isActive,
  }) async {
    await _dio.put(
      '/chart-of-accounts/$accountId',
      data: {
        if (accountCode != null) 'account_code': accountCode.trim(),
        if (name != null) 'name': name.trim(),
        if (type != null) 'type': type.trim(),
        if (subtype != null) 'subtype': subtype.trim(),
        if (parentId != null) 'parent_id': parentId,
        if (isActive != null) 'is_active': isActive,
      },
    );
  }

  Future<List<BankAccountDto>> getBankAccounts() async {
    final res = await _dio.get('/bank-accounts');
    final list = _extractList(res);
    return list.map((e) => BankAccountDto.fromJson(e)).toList();
  }

  Future<void> createBankAccount({
    required int ledgerAccountId,
    required String accountName,
    required String bankName,
    String? accountNumberMasked,
    String? branchName,
    String? currencyCode,
    String? statementImportHint,
    double openingBalance = 0,
    int? defaultLocationId,
    bool isActive = true,
  }) async {
    await _dio.post(
      '/bank-accounts',
      data: {
        'ledger_account_id': ledgerAccountId,
        'account_name': accountName.trim(),
        'bank_name': bankName.trim(),
        if ((accountNumberMasked ?? '').trim().isNotEmpty)
          'account_number_masked': accountNumberMasked!.trim(),
        if ((branchName ?? '').trim().isNotEmpty)
          'branch_name': branchName!.trim(),
        if ((currencyCode ?? '').trim().isNotEmpty)
          'currency_code': currencyCode!.trim(),
        if ((statementImportHint ?? '').trim().isNotEmpty)
          'statement_import_hint': statementImportHint!.trim(),
        if (defaultLocationId != null) 'default_location_id': defaultLocationId,
        'opening_balance': openingBalance,
        'is_active': isActive,
      },
    );
  }

  Future<void> updateBankAccount({
    required int bankAccountId,
    int? ledgerAccountId,
    String? accountName,
    String? bankName,
    String? accountNumberMasked,
    String? branchName,
    String? currencyCode,
    String? statementImportHint,
    double? openingBalance,
    int? defaultLocationId,
    bool? isActive,
  }) async {
    await _dio.put(
      '/bank-accounts/$bankAccountId',
      data: {
        if (ledgerAccountId != null) 'ledger_account_id': ledgerAccountId,
        if (accountName != null) 'account_name': accountName.trim(),
        if (bankName != null) 'bank_name': bankName.trim(),
        if (accountNumberMasked != null)
          'account_number_masked': accountNumberMasked.trim(),
        if (branchName != null) 'branch_name': branchName.trim(),
        if (currencyCode != null) 'currency_code': currencyCode.trim(),
        if (statementImportHint != null)
          'statement_import_hint': statementImportHint.trim(),
        if (openingBalance != null) 'opening_balance': openingBalance,
        if (defaultLocationId != null) 'default_location_id': defaultLocationId,
        if (isActive != null) 'is_active': isActive,
      },
    );
  }

  Future<List<BankStatementEntryDto>> getBankStatementEntries({
    required int bankAccountId,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 200,
  }) async {
    final res = await _dio.get(
      '/bank-accounts/$bankAccountId/statements',
      queryParameters: {
        if ((status ?? '').trim().isNotEmpty) 'status': status!.trim(),
        if (dateFrom != null) 'date_from': dateFrom.toIso8601String(),
        if (dateTo != null) 'date_to': dateTo.toIso8601String(),
        'limit': limit,
      },
    );
    final list = _extractList(res);
    return list.map((e) => BankStatementEntryDto.fromJson(e)).toList();
  }

  Future<void> createBankStatementEntry({
    required int bankAccountId,
    required DateTime entryDate,
    DateTime? valueDate,
    String? description,
    String? reference,
    String? externalRef,
    double depositAmount = 0,
    double withdrawalAmount = 0,
    double? runningBalance,
    String? reviewReason,
    String? idempotencyKey,
  }) async {
    final idem = (idempotencyKey ?? '').trim();
    await _dio.post(
      '/bank-accounts/$bankAccountId/statements',
      data: {
        'entry_date': entryDate.toIso8601String(),
        if (valueDate != null) 'value_date': valueDate.toIso8601String(),
        if ((description ?? '').trim().isNotEmpty)
          'description': description!.trim(),
        if ((reference ?? '').trim().isNotEmpty) 'reference': reference!.trim(),
        if ((externalRef ?? '').trim().isNotEmpty)
          'external_ref': externalRef!.trim(),
        if (depositAmount > 0) 'deposit_amount': depositAmount,
        if (withdrawalAmount > 0) 'withdrawal_amount': withdrawalAmount,
        if (runningBalance != null) 'running_balance': runningBalance,
        if ((reviewReason ?? '').trim().isNotEmpty)
          'review_reason': reviewReason!.trim(),
      },
      options: Options(
        headers: {
          if (idem.isNotEmpty) 'Idempotency-Key': idem,
          if (idem.isNotEmpty) 'X-Idempotency-Key': idem,
        },
      ),
    );
  }

  Future<void> matchBankStatement({
    required int bankAccountId,
    required int statementEntryId,
    required int ledgerEntryId,
    required double matchedAmount,
    String? notes,
  }) async {
    await _dio.post(
      '/bank-accounts/$bankAccountId/reconcile',
      data: {
        'statement_entry_id': statementEntryId,
        'ledger_entry_id': ledgerEntryId,
        'matched_amount': matchedAmount,
        if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
      },
    );
  }

  Future<void> unmatchBankStatement({
    required int bankAccountId,
    required int statementEntryId,
    required int matchId,
  }) async {
    await _dio.post(
      '/bank-accounts/$bankAccountId/unmatch',
      data: {
        'statement_entry_id': statementEntryId,
        'match_id': matchId,
      },
    );
  }

  Future<void> reviewBankStatement({
    required int bankAccountId,
    required int statementEntryId,
    String? reviewReason,
  }) async {
    await _dio.post(
      '/bank-accounts/$bankAccountId/review',
      data: {
        'statement_entry_id': statementEntryId,
        if ((reviewReason ?? '').trim().isNotEmpty)
          'review_reason': reviewReason!.trim(),
      },
    );
  }

  Future<void> createBankAdjustment({
    required int bankAccountId,
    required int statementEntryId,
    required String adjustmentType,
    required int offsetAccountId,
    String? reference,
    String? description,
    DateTime? date,
    String? idempotencyKey,
  }) async {
    final idem = (idempotencyKey ?? '').trim();
    await _dio.post(
      '/bank-accounts/$bankAccountId/adjustment',
      data: {
        'statement_entry_id': statementEntryId,
        'adjustment_type': adjustmentType.trim(),
        'offset_account_id': offsetAccountId,
        if ((reference ?? '').trim().isNotEmpty) 'reference': reference!.trim(),
        if ((description ?? '').trim().isNotEmpty)
          'description': description!.trim(),
        if (date != null) 'date': date.toIso8601String(),
      },
      options: Options(
        headers: {
          if (idem.isNotEmpty) 'Idempotency-Key': idem,
          if (idem.isNotEmpty) 'X-Idempotency-Key': idem,
        },
      ),
    );
  }

  Future<List<AccountingPeriodDto>> getAccountingPeriods() async {
    final res = await _dio.get('/accounting-periods');
    final list = _extractList(res);
    return list.map((e) => AccountingPeriodDto.fromJson(e)).toList();
  }

  Future<void> createAccountingPeriod({
    required String periodName,
    required DateTime startDate,
    required DateTime endDate,
    String? notes,
  }) async {
    await _dio.post(
      '/accounting-periods',
      data: {
        'period_name': periodName.trim(),
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
      },
    );
  }

  Future<void> closeAccountingPeriod({
    required int periodId,
    String? notes,
  }) async {
    await _dio.post(
      '/accounting-periods/$periodId/close',
      data: {
        if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
      },
    );
  }

  Future<void> reopenAccountingPeriod({
    required int periodId,
    String? notes,
  }) async {
    await _dio.post(
      '/accounting-periods/$periodId/reopen',
      data: {
        if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
      },
    );
  }

  Future<List<LedgerBalanceDto>> getLedgerBalances() async {
    final res = await _dio.get('/ledgers');
    final list = _extractList(res);
    return list.map((e) => LedgerBalanceDto.fromJson(e)).toList();
  }

  Future<PaginatedResult<LedgerEntryDto>> getLedgerEntries({
    required int accountId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    final qp = <String, dynamic>{
      if (dateFrom != null) 'date_from': dateFrom.toIso8601String(),
      if (dateTo != null) 'date_to': dateTo.toIso8601String(),
      'page': page,
      'per_page': perPage,
    };
    final res =
        await _dio.get('/ledgers/$accountId/entries', queryParameters: qp);
    return _extractPaginated(res, LedgerEntryDto.fromJson);
  }

  Future<List<AuditLogDto>> getAuditLogs({
    int? userId,
    String? action,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final qp = <String, dynamic>{
      if (userId != null) 'user_id': userId,
      if (action != null && action.trim().isNotEmpty) 'action': action.trim(),
      if (fromDate != null) 'from_date': fromDate.toIso8601String(),
      if (toDate != null) 'to_date': toDate.toIso8601String(),
    };
    final res =
        await _dio.get('/audit-logs', queryParameters: qp.isEmpty ? null : qp);
    final list = _extractList(res);
    return list.map((e) => AuditLogDto.fromJson(e)).toList();
  }

  Future<FinanceIntegrityDiagnosticsDto> getFinanceDiagnostics({
    String? status,
    int limit = 25,
  }) async {
    final qp = <String, dynamic>{
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      'limit': limit,
    };
    final res =
        await _dio.get('/finance-integrity/diagnostics', queryParameters: qp);
    return FinanceIntegrityDiagnosticsDto.fromJson(_extractMap(res));
  }

  Future<FinanceReplayResultDto> replayFinanceOutbox({
    List<int> outboxIds = const [],
    int limit = 50,
  }) async {
    final res = await _dio.post(
      '/finance-integrity/replay',
      data: {
        if (outboxIds.isNotEmpty) 'outbox_ids': outboxIds,
        'limit': limit,
      },
    );
    return FinanceReplayResultDto.fromJson(_extractMap(res));
  }

  Future<FinanceRepairLedgerResultDto> repairMissingLedger({
    int limit = 50,
  }) async {
    final res = await _dio.post(
      '/finance-integrity/repair-ledger',
      data: {'limit': limit},
    );
    return FinanceRepairLedgerResultDto.fromJson(_extractMap(res));
  }

  List<Map<String, dynamic>> _extractList(Response res) {
    final body = res.data;
    if (body is List) return body.cast<Map<String, dynamic>>();
    if (body is Map) {
      final data = body['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
    }
    return const [];
  }

  Map<String, dynamic> _extractMap(Response res) {
    final body = res.data;
    if (body is Map) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body.cast<String, dynamic>();
    }
    return const {};
  }

  PaginatedResult<T> _extractPaginated<T>(
    Response res,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final body = res.data;
    if (body is Map) {
      final data = body['data'];
      final meta = body['meta'];
      final list = data is List
          ? data.cast<Map<String, dynamic>>().map(fromJson).toList()
          : <T>[];
      final metaDto =
          meta is Map<String, dynamic> ? MetaDto.fromJson(meta) : null;
      return PaginatedResult(items: list, meta: metaDto);
    }
    return PaginatedResult(items: const [], meta: null);
  }
}

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AccountsRepository(dio, ref);
});
