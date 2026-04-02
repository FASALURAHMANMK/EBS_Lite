import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/locale_preferences.dart';
import '../../../dashboard/controllers/location_notifier.dart';
import '../../../admin/data/roles_repository.dart';
import '../../data/hr_repository.dart';
import '../../data/models.dart';
import '../../../../core/error_handler.dart';

class EmployeeFormPage extends ConsumerStatefulWidget {
  const EmployeeFormPage({super.key, this.employee});

  final EmployeeDto? employee;

  @override
  ConsumerState<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends ConsumerState<EmployeeFormPage> {
  bool _saving = false;
  bool _loadingMasters = true;
  Object? _mastersError;

  int? _locationId;
  int? _departmentId;
  int? _designationId;
  bool _isActive = true;
  DateTime? _hireDate;
  bool _isAppUser = false;
  int? _appRoleId;
  List<DepartmentDto> _departments = const [];
  List<DesignationDto> _designations = const [];
  List<RoleDto> _appRoles = const [];

  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _jobTitleCtrl;
  late final TextEditingController _salaryCtrl;
  late final TextEditingController _leaveBalanceCtrl;
  late final TextEditingController _appUsernameCtrl;
  late final TextEditingController _appEmailCtrl;
  late final TextEditingController _tempPasswordCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;

    final selectedLocation = ref.read(locationNotifierProvider).selected;
    _locationId = e?.locationId ?? selectedLocation?.locationId;
    _departmentId = e?.departmentId;
    _designationId = e?.designationId;
    _isActive = e?.isActive ?? true;
    _hireDate = e?.hireDate;

    _codeCtrl = TextEditingController(text: e?.employeeCode ?? '');
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _jobTitleCtrl = TextEditingController(text: e?.position ?? '');
    _salaryCtrl = TextEditingController(
        text: e?.salary == null ? '' : e!.salary!.toStringAsFixed(2));
    _leaveBalanceCtrl = TextEditingController(
        text: e?.leaveBalance == null ? '' : e!.leaveBalance!.toString());

    _appUsernameCtrl = TextEditingController();
    _appEmailCtrl = TextEditingController();
    _tempPasswordCtrl = TextEditingController();

    _loadMasters();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _jobTitleCtrl.dispose();
    _salaryCtrl.dispose();
    _leaveBalanceCtrl.dispose();
    _appUsernameCtrl.dispose();
    _appEmailCtrl.dispose();
    _tempPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() {
      _loadingMasters = true;
      _mastersError = null;
    });
    try {
      final repo = ref.read(hrRepositoryProvider);
      final depts = await repo.getDepartments();
      final designations = await repo.getDesignations();

      List<RoleDto> appRoles = const [];
      try {
        appRoles = await ref.read(rolesRepositoryProvider).listRoles();
      } catch (_) {
        appRoles = const [];
      }

      if (!mounted) return;
      setState(() {
        _departments = depts;
        _designations = designations;
        _appRoles = appRoles;
        _loadingMasters = false;
      });

      final e = widget.employee;
      if (e != null) {
        if (_departmentId == null &&
            (e.department ?? '').trim().isNotEmpty &&
            _departments.isNotEmpty) {
          final match = _departments.firstWhere(
            (d) => d.name.toLowerCase() == e.department!.trim().toLowerCase(),
            orElse: () => const DepartmentDto(
              departmentId: 0,
              name: '',
              isActive: true,
            ),
          );
          if (match.departmentId > 0) {
            setState(() => _departmentId = match.departmentId);
          }
        }
        if (_designationId == null &&
            (e.position ?? '').trim().isNotEmpty &&
            _designations.isNotEmpty) {
          final match = _designations.firstWhere(
            (r) => r.name.toLowerCase() == e.position!.trim().toLowerCase(),
            orElse: () => const DesignationDto(
              designationId: 0,
              departmentId: null,
              defaultAppRoleId: null,
              name: '',
              description: null,
              isActive: true,
            ),
          );
          if (match.designationId > 0) {
            setState(() => _designationId = match.designationId);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mastersError = e;
        _loadingMasters = false;
      });
    }
  }

  void _generateTempPassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';
    final rand = Random.secure();
    final pw =
        List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
    setState(() => _tempPasswordCtrl.text = pw);
  }

  Future<void> _pickHireDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDate ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _hireDate = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    if (_isAppUser && widget.employee == null) {
      final username = _appUsernameCtrl.text.trim();
      final email = _appEmailCtrl.text.trim().isEmpty
          ? _emailCtrl.text.trim()
          : _appEmailCtrl.text.trim();
      final pw = _tempPasswordCtrl.text.trim();
      if (username.length < 3 || email.isEmpty || pw.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid app user details')),
        );
        return;
      }
      if (_appRoleId == null || _appRoleId! <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an app role')),
        );
        return;
      }
    }
    final salary = double.tryParse(_salaryCtrl.text.trim());
    final leaveBal = double.tryParse(_leaveBalanceCtrl.text.trim());

    setState(() => _saving = true);
    try {
      final repo = ref.read(hrRepositoryProvider);
      if (widget.employee == null) {
        await repo.createEmployee(
          locationId: _locationId,
          employeeCode: _codeCtrl.text.trim(),
          name: name,
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          position: _jobTitleCtrl.text.trim(),
          departmentId: _departmentId,
          designationId: _designationId,
          salary: salary,
          hireDate: _hireDate,
          isActive: _isActive,
          leaveBalance: leaveBal,
          isAppUser: _isAppUser,
          appUsername: _appUsernameCtrl.text.trim(),
          appEmail: _appEmailCtrl.text.trim().isEmpty
              ? _emailCtrl.text.trim()
              : _appEmailCtrl.text.trim(),
          tempPassword: _tempPasswordCtrl.text.trim(),
          appRoleId: _appRoleId,
        );
      } else {
        await repo.updateEmployee(
          widget.employee!.employeeId,
          locationId: _locationId,
          employeeCode: _codeCtrl.text.trim(),
          name: name,
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          position: _jobTitleCtrl.text.trim(),
          departmentId: _departmentId,
          designationId: _designationId,
          salary: salary,
          hireDate: _hireDate,
          isActive: _isActive,
          leaveBalance: leaveBal,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationsState = ref.watch(locationNotifierProvider);
    final locations = locationsState.locations;

    final uniqueDepartmentsById = <int, DepartmentDto>{};
    for (final d in _departments) {
      uniqueDepartmentsById[d.departmentId] = d;
    }
    final uniqueDepartments = uniqueDepartmentsById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final uniqueDesignationsById = <int, DesignationDto>{};
    for (final d in _designations) {
      uniqueDesignationsById[d.designationId] = d;
    }
    final allDesignations = uniqueDesignationsById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final uniqueAppRolesById = <int, RoleDto>{};
    for (final r in _appRoles) {
      uniqueAppRolesById[r.roleId] = r;
    }
    final uniqueAppRoles = uniqueAppRolesById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final safeLocationId =
        _locationId == null || locations.any((l) => l.locationId == _locationId)
            ? _locationId
            : null;
    final safeDepartmentId = _departmentId == null ||
            uniqueDepartments.any((d) => d.departmentId == _departmentId)
        ? _departmentId
        : null;

    final visibleDesignations = allDesignations
        .where((d) => d.departmentId == safeDepartmentId)
        .toList(growable: false);

    final safeDesignationId = _designationId == null ||
            visibleDesignations.any((d) => d.designationId == _designationId)
        ? _designationId
        : null;
    final safeAppRoleId =
        _appRoleId == null || uniqueAppRoles.any((r) => r.roleId == _appRoleId)
            ? _appRoleId
            : null;

    final localePrefs = ref.watch(localePreferencesProvider);
    final hireLabel = _hireDate == null
        ? 'Select'
        : AppDateTime.formatDate(context, localePrefs, _hireDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee == null ? 'Add Employee' : 'Edit Employee'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
          )
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loadingMasters)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            if (_mastersError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Failed to load master data: ${ErrorHandler.message(_mastersError!)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (locations.isNotEmpty)
              DropdownButtonFormField<int?>(
                isExpanded: true,
                key: ValueKey(safeLocationId),
                initialValue: safeLocationId,
                decoration: const InputDecoration(labelText: 'Location'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All / Unassigned'),
                  ),
                  ...locations.map(
                    (l) => DropdownMenuItem<int?>(
                      value: l.locationId,
                      child: Text(l.name),
                    ),
                  ),
                ],
                onChanged:
                    _saving ? null : (v) => setState(() => _locationId = v),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Employee ID (auto-generated if blank)',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.email_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
                prefixIcon: Icon(Icons.location_on_rounded),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    isExpanded: true,
                    key: ValueKey(safeDepartmentId),
                    initialValue: safeDepartmentId,
                    decoration: const InputDecoration(
                      labelText: 'Department (optional)',
                      prefixIcon: Icon(Icons.apartment_rounded),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Unassigned'),
                      ),
                      ...uniqueDepartments.map(
                        (d) => DropdownMenuItem<int?>(
                          value: d.departmentId,
                          child: Text(d.name),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() {
                              _departmentId = v;
                              _designationId = null;
                            }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    isExpanded: true,
                    key: ValueKey(safeDesignationId),
                    initialValue: safeDesignationId,
                    decoration: const InputDecoration(
                      labelText: 'Designation (optional)',
                      prefixIcon: Icon(Icons.work_rounded),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Unassigned'),
                      ),
                      ...visibleDesignations.map(
                        (d) => DropdownMenuItem<int?>(
                          value: d.designationId,
                          child: Text(d.name),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(() {
                              _designationId = v;
                              if (_isAppUser &&
                                  (_appRoleId == null || _appRoleId! <= 0) &&
                                  v != null) {
                                final match = allDesignations
                                    .where((d) => d.designationId == v);
                                if (match.isNotEmpty) {
                                  final roleId = match.first.defaultAppRoleId;
                                  if (roleId != null && roleId > 0) {
                                    _appRoleId = roleId;
                                  }
                                }
                              }
                            }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jobTitleCtrl,
              decoration: const InputDecoration(
                labelText: 'Job title (optional)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _salaryCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Salary (optional)',
                      prefixIcon: Icon(Icons.payments_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _leaveBalanceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Leave Balance (optional)',
                      prefixIcon: Icon(Icons.beach_access_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickHireDate,
              icon: const Icon(Icons.event_rounded),
              label: Text('Hire date: $hireLabel'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _isActive,
              onChanged: _saving ? null : (v) => setState(() => _isActive = v),
              title: const Text('Active'),
            ),
            if (widget.employee == null) ...[
              const Divider(height: 24),
              SwitchListTile(
                value: _isAppUser,
                onChanged: _saving
                    ? null
                    : (v) => setState(() {
                          _isAppUser = v;
                          if (v &&
                              (_appRoleId == null || _appRoleId! <= 0) &&
                              safeDesignationId != null) {
                            final match = allDesignations.where(
                              (d) => d.designationId == safeDesignationId,
                            );
                            if (match.isNotEmpty) {
                              final roleId = match.first.defaultAppRoleId;
                              if (roleId != null && roleId > 0) {
                                _appRoleId = roleId;
                              }
                            }
                          }
                        }),
                title: const Text('Is app user'),
                subtitle: const Text(
                  'Create a login for this employee with a temporary password',
                ),
              ),
              if (_isAppUser) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _appUsernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _appEmailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Login Email (optional: defaults to employee)',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  key: ValueKey(safeAppRoleId),
                  initialValue: safeAppRoleId,
                  decoration: const InputDecoration(
                    labelText: 'App Role',
                    prefixIcon: Icon(Icons.security_rounded),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Select role'),
                    ),
                    ...uniqueAppRoles.map(
                      (r) => DropdownMenuItem<int?>(
                        value: r.roleId,
                        child: Text(r.name),
                      ),
                    ),
                  ],
                  onChanged:
                      _saving ? null : (v) => setState(() => _appRoleId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tempPasswordCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Temporary password',
                          prefixIcon: Icon(Icons.password_rounded),
                        ),
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _generateTempPassword,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text('Generate'),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
