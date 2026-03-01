import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import 'models.dart';

class HrRepository {
  HrRepository(this._dio);

  final Dio _dio;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  Future<AttendanceDto> checkIn(int employeeId) async {
    final res = await _dio.post(
      '/attendance/check-in',
      data: {'employee_id': employeeId},
    );
    final data = _extractMap(res);
    return AttendanceDto.fromJson(data);
  }

  Future<AttendanceDto> checkOut(int employeeId) async {
    final res = await _dio.post(
      '/attendance/check-out',
      data: {'employee_id': employeeId},
    );
    final data = _extractMap(res);
    return AttendanceDto.fromJson(data);
  }

  Future<LeaveDto> applyLeave({
    required int employeeId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final res = await _dio.post(
      '/attendance/leave',
      data: {
        'employee_id': employeeId,
        'start_date': _dateFormat.format(startDate),
        'end_date': _dateFormat.format(endDate),
        'reason': reason,
      },
    );
    final data = _extractMap(res);
    return LeaveDto.fromJson(data);
  }

  Future<List<HolidayDto>> getHolidays() async {
    final res = await _dio.get('/attendance/holidays');
    final list = _extractList(res);
    return list.map(HolidayDto.fromJson).toList();
  }

  Future<List<AttendanceDto>> getRecords({
    int? employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final qp = <String, dynamic>{
      if (employeeId != null) 'employee_id': employeeId,
      if (startDate != null) 'start_date': _dateFormat.format(startDate),
      if (endDate != null) 'end_date': _dateFormat.format(endDate),
    };
    final res = await _dio.get('/attendance/records',
        queryParameters: qp.isEmpty ? null : qp);
    final list = _extractList(res);
    return list.map(AttendanceDto.fromJson).toList();
  }

  Future<List<PayrollDto>> getPayrolls({
    int? employeeId,
    String? month,
  }) async {
    final qp = <String, dynamic>{
      if (employeeId != null) 'employee_id': employeeId,
      if (month != null && month.trim().isNotEmpty) 'month': month.trim(),
    };
    final res =
        await _dio.get('/payrolls', queryParameters: qp.isEmpty ? null : qp);
    final list = _extractList(res);
    return list.map(PayrollDto.fromJson).toList();
  }

  Future<PayrollDto> createPayroll({
    required int employeeId,
    required String month,
    required double basicSalary,
    required double allowances,
    required double deductions,
  }) async {
    final res = await _dio.post(
      '/payrolls',
      data: {
        'employee_id': employeeId,
        'month': month,
        'basic_salary': basicSalary,
        'allowances': allowances,
        'deductions': deductions,
      },
    );
    final data = _extractMap(res);
    return PayrollDto.fromJson(data);
  }

  Future<void> markPaid(int payrollId) async {
    await _dio.put('/payrolls/$payrollId/mark-paid');
  }

  Future<PayslipDto> getPayslip(int payrollId) async {
    final res = await _dio.get('/payrolls/$payrollId/payslip');
    final data = _extractMap(res);
    return PayslipDto.fromJson(data);
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
}

final hrRepositoryProvider = Provider<HrRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HrRepository(dio);
});
