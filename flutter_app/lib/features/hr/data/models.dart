import 'package:intl/intl.dart';

class EmployeeDto {
  final int employeeId;
  final int companyId;
  final int? locationId;
  final String? employeeCode;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? position;
  final String? department;
  final int? departmentId;
  final int? designationId;
  final double? salary;
  final DateTime? hireDate;
  final bool isActive;
  final DateTime? lastCheckIn;
  final DateTime? lastCheckOut;
  final double? leaveBalance;
  final int? userId;

  EmployeeDto({
    required this.employeeId,
    required this.companyId,
    required this.locationId,
    required this.employeeCode,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.position,
    required this.department,
    required this.departmentId,
    required this.designationId,
    required this.salary,
    required this.hireDate,
    required this.isActive,
    required this.lastCheckIn,
    required this.lastCheckOut,
    required this.leaveBalance,
    required this.userId,
  });

  factory EmployeeDto.fromJson(Map<String, dynamic> json) => EmployeeDto(
        employeeId: _asInt(json['employee_id']),
        companyId: _asInt(json['company_id']),
        locationId: _asNullableInt(json['location_id']),
        employeeCode: json['employee_code']?.toString(),
        name: (json['name'] ?? '').toString(),
        phone: json['phone']?.toString(),
        email: json['email']?.toString(),
        address: json['address']?.toString(),
        position: json['position']?.toString(),
        department: json['department']?.toString(),
        departmentId: _asNullableInt(json['department_id']),
        designationId: _asNullableInt(json['designation_id']),
        salary: _asNullableDouble(json['salary']),
        hireDate: _asNullableDate(json['hire_date']),
        isActive: (json['is_active'] as bool?) ?? true,
        lastCheckIn: _asNullableDate(json['last_check_in']),
        lastCheckOut: _asNullableDate(json['last_check_out']),
        leaveBalance: _asNullableDouble(json['leave_balance']),
        userId: _asNullableInt(json['user_id']),
      );
}

class DepartmentDto {
  final int departmentId;
  final String name;
  final bool isActive;

  const DepartmentDto({
    required this.departmentId,
    required this.name,
    required this.isActive,
  });

  factory DepartmentDto.fromJson(Map<String, dynamic> json) => DepartmentDto(
        departmentId: _asInt(json['department_id']),
        name: (json['name'] ?? '').toString(),
        isActive: (json['is_active'] as bool?) ?? true,
      );
}

class DesignationDto {
  final int designationId;
  final int? departmentId;
  final int? defaultAppRoleId;
  final String name;
  final String? description;
  final bool isActive;

  const DesignationDto({
    required this.designationId,
    required this.departmentId,
    required this.defaultAppRoleId,
    required this.name,
    required this.description,
    required this.isActive,
  });

  factory DesignationDto.fromJson(Map<String, dynamic> json) => DesignationDto(
        designationId: _asInt(json['designation_id']),
        departmentId: _asNullableInt(json['department_id']),
        defaultAppRoleId: _asNullableInt(json['default_app_role_id']),
        name: (json['name'] ?? '').toString(),
        description: json['description']?.toString(),
        isActive: (json['is_active'] as bool?) ?? true,
      );
}

class AttendanceDto {
  final int attendanceId;
  final int employeeId;
  final DateTime checkIn;
  final DateTime? checkOut;

  AttendanceDto({
    required this.attendanceId,
    required this.employeeId,
    required this.checkIn,
    required this.checkOut,
  });

  factory AttendanceDto.fromJson(Map<String, dynamic> json) => AttendanceDto(
        attendanceId: _asInt(json['attendance_id']),
        employeeId: _asInt(json['employee_id']),
        checkIn: _asDate(json['check_in']),
        checkOut: _asNullableDate(json['check_out']),
      );
}

class LeaveDto {
  final int leaveId;
  final int employeeId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;

  LeaveDto({
    required this.leaveId,
    required this.employeeId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
  });

  factory LeaveDto.fromJson(Map<String, dynamic> json) => LeaveDto(
        leaveId: _asInt(json['leave_id']),
        employeeId: _asInt(json['employee_id']),
        startDate: _asDate(json['start_date']),
        endDate: _asDate(json['end_date']),
        reason: (json['reason'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
      );
}

class LeaveApprovalDto {
  final int leaveId;
  final int employeeId;
  final String employeeName;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;
  final int? approvedBy;
  final DateTime? approvedAt;
  final String? decisionNotes;
  final DateTime? createdAt;

  const LeaveApprovalDto({
    required this.leaveId,
    required this.employeeId,
    required this.employeeName,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.approvedBy,
    required this.approvedAt,
    required this.decisionNotes,
    required this.createdAt,
  });

  factory LeaveApprovalDto.fromJson(Map<String, dynamic> json) =>
      LeaveApprovalDto(
        leaveId: _asInt(json['leave_id']),
        employeeId: _asInt(json['employee_id']),
        employeeName: (json['employee_name'] ?? '').toString(),
        startDate: _asDate(json['start_date']),
        endDate: _asDate(json['end_date']),
        reason: (json['reason'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        approvedBy: _asNullableInt(json['approved_by']),
        approvedAt: _asNullableDate(json['approved_at']),
        decisionNotes: json['decision_notes']?.toString(),
        createdAt: _asNullableDate(json['created_at']),
      );
}

class HolidayDto {
  final int holidayId;
  final DateTime date;
  final String name;

  HolidayDto({
    required this.holidayId,
    required this.date,
    required this.name,
  });

  factory HolidayDto.fromJson(Map<String, dynamic> json) => HolidayDto(
        holidayId: _asInt(json['holiday_id']),
        date: _asDate(json['date']),
        name: (json['name'] ?? '').toString(),
      );
}

class PayrollDto {
  final int payrollId;
  final int employeeId;
  final DateTime payPeriodStart;
  final DateTime payPeriodEnd;
  final double basicSalary;
  final double grossSalary;
  final double totalDeductions;
  final double netSalary;
  final String status;
  final int? processedBy;

  PayrollDto({
    required this.payrollId,
    required this.employeeId,
    required this.payPeriodStart,
    required this.payPeriodEnd,
    required this.basicSalary,
    required this.grossSalary,
    required this.totalDeductions,
    required this.netSalary,
    required this.status,
    required this.processedBy,
  });

  factory PayrollDto.fromJson(Map<String, dynamic> json) => PayrollDto(
        payrollId: _asInt(json['payroll_id']),
        employeeId: _asInt(json['employee_id']),
        payPeriodStart: _asDate(json['pay_period_start']),
        payPeriodEnd: _asDate(json['pay_period_end']),
        basicSalary: _asDouble(json['basic_salary']),
        grossSalary: _asDouble(json['gross_salary']),
        totalDeductions: _asDouble(json['total_deductions']),
        netSalary: _asDouble(json['net_salary']),
        status: (json['status'] ?? '').toString(),
        processedBy: _asNullableInt(json['processed_by']),
      );
}

class PayrollCalculationDto {
  final int employeeId;
  final String month;
  final DateTime payPeriodStart;
  final DateTime payPeriodEnd;
  final double baseMonthlySalary;
  final int workingDays;
  final double payableDays;
  final double presentDays;
  final double approvedLeaveDays;
  final double unpaidAbsenceDays;
  final double proratedBasicSalary;

  const PayrollCalculationDto({
    required this.employeeId,
    required this.month,
    required this.payPeriodStart,
    required this.payPeriodEnd,
    required this.baseMonthlySalary,
    required this.workingDays,
    required this.payableDays,
    required this.presentDays,
    required this.approvedLeaveDays,
    required this.unpaidAbsenceDays,
    required this.proratedBasicSalary,
  });

  factory PayrollCalculationDto.fromJson(Map<String, dynamic> json) =>
      PayrollCalculationDto(
        employeeId: _asInt(json['employee_id']),
        month: (json['month'] ?? '').toString(),
        payPeriodStart: _asDate(json['pay_period_start']),
        payPeriodEnd: _asDate(json['pay_period_end']),
        baseMonthlySalary: _asDouble(json['base_monthly_salary']),
        workingDays: _asInt(json['working_days']),
        payableDays: _asDouble(json['payable_days']),
        presentDays: _asDouble(json['present_days']),
        approvedLeaveDays: _asDouble(json['approved_leave_days']),
        unpaidAbsenceDays: _asDouble(json['unpaid_absence_days']),
        proratedBasicSalary: _asDouble(json['prorated_basic_salary']),
      );
}

class SalaryComponentDto {
  final int componentId;
  final int payrollId;
  final String type;
  final double amount;

  SalaryComponentDto({
    required this.componentId,
    required this.payrollId,
    required this.type,
    required this.amount,
  });

  factory SalaryComponentDto.fromJson(Map<String, dynamic> json) =>
      SalaryComponentDto(
        componentId: _asInt(json['component_id']),
        payrollId: _asInt(json['payroll_id']),
        type: (json['type'] ?? '').toString(),
        amount: _asDouble(json['amount']),
      );
}

class AdvanceDto {
  final int advanceId;
  final int payrollId;
  final double amount;
  final DateTime date;

  AdvanceDto({
    required this.advanceId,
    required this.payrollId,
    required this.amount,
    required this.date,
  });

  factory AdvanceDto.fromJson(Map<String, dynamic> json) => AdvanceDto(
        advanceId: _asInt(json['advance_id']),
        payrollId: _asInt(json['payroll_id']),
        amount: _asDouble(json['amount']),
        date: _asDate(json['date']),
      );
}

class DeductionDto {
  final int deductionId;
  final int payrollId;
  final String type;
  final double amount;
  final DateTime date;

  DeductionDto({
    required this.deductionId,
    required this.payrollId,
    required this.type,
    required this.amount,
    required this.date,
  });

  factory DeductionDto.fromJson(Map<String, dynamic> json) => DeductionDto(
        deductionId: _asInt(json['deduction_id']),
        payrollId: _asInt(json['payroll_id']),
        type: (json['type'] ?? '').toString(),
        amount: _asDouble(json['amount']),
        date: _asDate(json['date']),
      );
}

class PayslipDto {
  final PayrollDto payroll;
  final List<SalaryComponentDto> components;
  final List<AdvanceDto> advances;
  final List<DeductionDto> deductions;
  final double netPay;

  PayslipDto({
    required this.payroll,
    required this.components,
    required this.advances,
    required this.deductions,
    required this.netPay,
  });

  factory PayslipDto.fromJson(Map<String, dynamic> json) => PayslipDto(
        payroll: PayrollDto.fromJson(json['payroll'] as Map<String, dynamic>),
        components: (json['components'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(SalaryComponentDto.fromJson)
            .toList(),
        advances: (json['advances'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(AdvanceDto.fromJson)
            .toList(),
        deductions: (json['deductions'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(DeductionDto.fromJson)
            .toList(),
        netPay: _asDouble(json['net_pay']),
      );
}

String formatShortDate(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
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
  if (v is String) return DateTime.tryParse(v) ?? DateTime(1970);
  return DateTime(1970);
}

DateTime? _asNullableDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}
