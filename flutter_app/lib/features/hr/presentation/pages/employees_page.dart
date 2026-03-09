import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../data/hr_repository.dart';
import '../../data/models.dart';
import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import 'employee_form_page.dart';

class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> {
  bool _loading = true;
  Object? _error;
  List<EmployeeDto> _employees = const [];

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _departmentCtrl = TextEditingController();
  String _status = 'all'; // all | active | inactive

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _departmentCtrl.dispose();
    super.dispose();
  }

  bool? _statusToIsActive() {
    switch (_status) {
      case 'active':
        return true;
      case 'inactive':
        return false;
      default:
        return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(hrRepositoryProvider);
      final list = await repo.getEmployees(
        department: _departmentCtrl.text.trim().isEmpty
            ? null
            : _departmentCtrl.text.trim(),
        isActive: _statusToIsActive(),
      );
      if (!mounted) return;
      setState(() => _employees = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EmployeeFormPage()),
    );
    if (created == true) {
      await _load();
    }
  }

  Future<void> _openEdit(EmployeeDto employee) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EmployeeFormPage(employee: employee)),
    );
    if (updated == true) {
      await _load();
    }
  }

  Future<void> _confirmDelete(EmployeeDto employee) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete employee?'),
        content: Text('Delete ${employee.name} (#${employee.employeeId})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(hrRepositoryProvider).deleteEmployee(employee.employeeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee deleted')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _employees
        : _employees.where((e) {
            final code = (e.employeeCode ?? '').toLowerCase();
            final name = e.name.toLowerCase();
            final phone = (e.phone ?? '').toLowerCase();
            final email = (e.email ?? '').toLowerCase();
            return name.contains(query) ||
                code.contains(query) ||
                phone.contains(query) ||
                email.contains(query) ||
                e.employeeId.toString().contains(query);
          }).toList();

    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.fromMenu,
        leading: widget.fromMenu
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : (isWide ? const DesktopSidebarToggleLeading() : null),
        leadingWidth: (!widget.fromMenu && isWide) ? 104 : null,
        title: const Text('Employees'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: widget.fromMenu
          ? DashboardSidebar(
              onSelect: (label) => widget.onMenuSelect?.call(context, label),
            )
          : null,
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: 'Add Employee',
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? AppErrorView(error: _error!, onRetry: _load)
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Search name, code, phone, email, ID',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 220,
                                  child: TextField(
                                    controller: _departmentCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Department (optional)',
                                    ),
                                    onChanged: (_) => _load(),
                                  ),
                                ),
                                DropdownButton<String>(
                                  value: _status,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'all', child: Text('All')),
                                    DropdownMenuItem(
                                        value: 'active', child: Text('Active')),
                                    DropdownMenuItem(
                                        value: 'inactive',
                                        child: Text('Inactive')),
                                  ],
                                  onChanged: (v) async {
                                    setState(() => _status = v ?? 'all');
                                    await _load();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No employees found'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final e = filtered[i];
                                  final subtitle = <String>[
                                    if (e.employeeCode != null &&
                                        e.employeeCode!.trim().isNotEmpty)
                                      'Code: ${e.employeeCode}',
                                    if (e.department != null &&
                                        e.department!.trim().isNotEmpty)
                                      'Dept: ${e.department}',
                                    if (e.position != null &&
                                        e.position!.trim().isNotEmpty)
                                      'Designation: ${e.position}',
                                    if (e.phone != null &&
                                        e.phone!.trim().isNotEmpty)
                                      'Phone: ${e.phone}',
                                    if (e.email != null &&
                                        e.email!.trim().isNotEmpty)
                                      'Email: ${e.email}',
                                    if (e.userId != null) 'User: #${e.userId}',
                                  ].join(' • ');

                                  return Card(
                                    elevation: 0,
                                    child: ListTile(
                                      leading: Icon(
                                        e.isActive
                                            ? Icons.verified_user_rounded
                                            : Icons.person_off_rounded,
                                      ),
                                      title:
                                          Text('${e.name} • #${e.employeeId}'),
                                      subtitle: subtitle.isEmpty
                                          ? const Text('—')
                                          : Text(subtitle),
                                      isThreeLine: subtitle.isNotEmpty,
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'edit') {
                                            _openEdit(e);
                                          } else if (v == 'delete') {
                                            _confirmDelete(e);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                        ],
                                      ),
                                      onTap: () => _openEdit(e),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}
