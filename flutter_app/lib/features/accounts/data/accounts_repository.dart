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
    int? locationId,
  }) async {
    final loc = locationId ?? _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    await _dio.post(
      '/cash-registers/close',
      data: {'closing_balance': closingBalance},
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  Future<void> recordCashTally({
    required double count,
    String? notes,
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
      },
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
    required int accountId,
    required double amount,
    required String reference,
    String? description,
  }) async {
    final res = await _dio.post(
      '/vouchers/$type',
      data: {
        'account_id': accountId,
        'amount': amount,
        'reference': reference.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    final data = _extractMap(res);
    return (data['voucher_id'] as int?) ?? 0;
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
