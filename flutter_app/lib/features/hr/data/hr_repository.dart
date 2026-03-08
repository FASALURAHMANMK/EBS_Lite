import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import 'models.dart';

class HrRepository {
  HrRepository(this._dio);

  final Dio _dio;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<EmployeeDto>> getEmployees({
    String? department,
    bool? isActive,
  }) async {
    final qp = <String, dynamic>{
      if (department != null && department.trim().isNotEmpty)
        'department': department.trim(),
      if (isActive != null) 'status': isActive ? 'active' : 'inactive',
    };
    final res =
        await _dio.get('/employees', queryParameters: qp.isEmpty ? null : qp);
    final list = _extractList(res);
    return list.map(EmployeeDto.fromJson).toList();
  }

  Future<EmployeeDto> createEmployee({
    int? locationId,
    String? employeeCode,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? position,
    String? department,
    int? departmentId,
    int? designationId,
    double? salary,
    DateTime? hireDate,
    bool? isActive,
    double? leaveBalance,
    bool isAppUser = false,
    String? appUsername,
    String? appEmail,
    String? tempPassword,
    int? appRoleId,
  }) async {
    final res = await _dio.post(
      '/employees',
      data: {
        if (locationId != null) 'location_id': locationId,
        if (employeeCode != null && employeeCode.trim().isNotEmpty)
          'employee_code': employeeCode.trim(),
        'name': name.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
        if (position != null && position.trim().isNotEmpty)
          'position': position.trim(),
        if (department != null && department.trim().isNotEmpty)
          'department': department.trim(),
        if (departmentId != null) 'department_id': departmentId,
        if (designationId != null) 'designation_id': designationId,
        if (salary != null) 'salary': salary,
        if (hireDate != null) 'hire_date': hireDate.toIso8601String(),
        if (isActive != null) 'is_active': isActive,
        if (leaveBalance != null) 'leave_balance': leaveBalance,
        if (isAppUser)
          'app_user': {
            'create': true,
            'username': (appUsername ?? '').trim(),
            'email': (appEmail ?? '').trim(),
            'temp_password': (tempPassword ?? '').trim(),
            'role_id': appRoleId,
            if (locationId != null) 'location_id': locationId,
          },
      },
    );
    final data = _extractMap(res);
    return EmployeeDto.fromJson(data);
  }

  Future<void> updateEmployee(
    int employeeId, {
    int? locationId,
    String? employeeCode,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? position,
    String? department,
    int? departmentId,
    int? designationId,
    double? salary,
    DateTime? hireDate,
    bool? isActive,
    double? leaveBalance,
  }) async {
    await _dio.put(
      '/employees/$employeeId',
      data: {
        if (locationId != null) 'location_id': locationId,
        if (employeeCode != null && employeeCode.trim().isNotEmpty)
          'employee_code': employeeCode.trim(),
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (position != null) 'position': position,
        if (department != null) 'department': department,
        if (departmentId != null) 'department_id': departmentId,
        if (designationId != null) 'designation_id': designationId,
        if (salary != null) 'salary': salary,
        if (hireDate != null) 'hire_date': hireDate.toIso8601String(),
        if (isActive != null) 'is_active': isActive,
        if (leaveBalance != null) 'leave_balance': leaveBalance,
      },
    );
  }

  Future<List<DepartmentDto>> getDepartments() async {
    final res = await _dio.get('/departments');
    final list = _extractList(res);
    return list.map(DepartmentDto.fromJson).toList();
  }

  Future<DepartmentDto> createDepartment({
    required String name,
    bool isActive = true,
  }) async {
    final res = await _dio.post('/departments', data: {
      'name': name.trim(),
      'is_active': isActive,
    });
    final data = _extractMap(res);
    return DepartmentDto.fromJson(data);
  }

  Future<void> updateDepartment(
    int departmentId, {
    String? name,
    bool? isActive,
  }) async {
    await _dio.put('/departments/$departmentId', data: {
      if (name != null) 'name': name.trim(),
      if (isActive != null) 'is_active': isActive,
    });
  }

  Future<void> deleteDepartment(int departmentId) async {
    await _dio.delete('/departments/$departmentId');
  }

  Future<List<DesignationDto>> getDesignations({int? departmentId}) async {
    final qp = <String, dynamic>{
      if (departmentId != null) 'department_id': departmentId,
    };
    final res = await _dio.get('/designations',
        queryParameters: qp.isEmpty ? null : qp);
    final list = _extractList(res);
    return list.map(DesignationDto.fromJson).toList();
  }

  Future<DesignationDto> createDesignation({
    required int departmentId,
    required String name,
    String? description,
    int? defaultAppRoleId,
    bool isActive = true,
  }) async {
    final res = await _dio.post('/designations', data: {
      'department_id': departmentId,
      if (defaultAppRoleId != null) 'default_app_role_id': defaultAppRoleId,
      'name': name.trim(),
      if (description != null) 'description': description,
      'is_active': isActive,
    });
    final data = _extractMap(res);
    return DesignationDto.fromJson(data);
  }

  Future<void> updateDesignation(
    int designationId, {
    int? departmentId,
    int? defaultAppRoleId,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    await _dio.put('/designations/$designationId', data: {
      if (departmentId != null) 'department_id': departmentId,
      if (defaultAppRoleId != null) 'default_app_role_id': defaultAppRoleId,
      if (name != null) 'name': name.trim(),
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
    });
  }

  Future<void> deleteDesignation(int designationId) async {
    await _dio.delete('/designations/$designationId');
  }

  Future<void> deleteEmployee(int employeeId) async {
    await _dio.delete('/employees/$employeeId');
  }

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

  Future<List<LeaveApprovalDto>> getLeaves({
    String? status,
    int? employeeId,
  }) async {
    final qp = <String, dynamic>{
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (employeeId != null) 'employee_id': employeeId,
    };
    final res = await _dio.get('/attendance/leaves',
        queryParameters: qp.isEmpty ? null : qp);
    final list = _extractList(res);
    return list.map(LeaveApprovalDto.fromJson).toList();
  }

  Future<void> approveLeave(int leaveId, {String? decisionNotes}) async {
    await _dio.put('/attendance/leaves/$leaveId/approve', data: {
      if (decisionNotes != null && decisionNotes.trim().isNotEmpty)
        'decision_notes': decisionNotes.trim(),
    });
  }

  Future<void> rejectLeave(int leaveId, {String? decisionNotes}) async {
    await _dio.put('/attendance/leaves/$leaveId/reject', data: {
      if (decisionNotes != null && decisionNotes.trim().isNotEmpty)
        'decision_notes': decisionNotes.trim(),
    });
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
    bool autoCalculate = false,
  }) async {
    final res = await _dio.post(
      '/payrolls',
      data: {
        'employee_id': employeeId,
        'month': month,
        'basic_salary': basicSalary,
        'allowances': allowances,
        'deductions': deductions,
        if (autoCalculate) 'auto_calculate': true,
      },
    );
    final data = _extractMap(res);
    return PayrollDto.fromJson(data);
  }

  Future<PayrollCalculationDto> calculatePayroll({
    required int employeeId,
    required String month,
    double? baseMonthlySalary,
  }) async {
    final qp = <String, dynamic>{
      'employee_id': employeeId,
      'month': month,
      if (baseMonthlySalary != null) 'base_monthly_salary': baseMonthlySalary,
    };
    final res = await _dio.get('/payrolls/calculate', queryParameters: qp);
    final data = _extractMap(res);
    return PayrollCalculationDto.fromJson(data);
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
