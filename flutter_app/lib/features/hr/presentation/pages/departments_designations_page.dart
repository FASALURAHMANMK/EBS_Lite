import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../../admin/data/roles_repository.dart';
import '../../data/hr_repository.dart';
import '../../data/models.dart';

class DepartmentsDesignationsPage extends ConsumerStatefulWidget {
  const DepartmentsDesignationsPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<DepartmentsDesignationsPage> createState() =>
      _DepartmentsDesignationsPageState();
}

class _DepartmentsDesignationsPageState
    extends ConsumerState<DepartmentsDesignationsPage> {
  bool _loading = true;
  Object? _error;
  List<DepartmentDto> _departments = const [];
  List<DesignationDto> _designations = const [];
  List<RoleDto> _appRoles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(hrRepositoryProvider);
      List<RoleDto> appRoles = const [];
      try {
        appRoles = await ref.read(rolesRepositoryProvider).listRoles();
      } catch (_) {
        appRoles = const [];
      }

      final res =
          await Future.wait([repo.getDepartments(), repo.getDesignations()]);
      if (!mounted) return;
      setState(() {
        _departments = (res[0] as List).cast<DepartmentDto>();
        _designations = (res[1] as List).cast<DesignationDto>();
        _appRoles = appRoles;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDepartment() async {
    final nameCtrl = TextEditingController();
    bool isActive = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Add Department'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  onChanged: (v) => setInner(() => isActive = v),
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(hrRepositoryProvider).createDepartment(
            name: nameCtrl.text,
            isActive: isActive,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department created')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _openEditDepartment(DepartmentDto d) async {
    final nameCtrl = TextEditingController(text: d.name);
    bool isActive = d.isActive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Edit Department'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  onChanged: (v) => setInner(() => isActive = v),
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(hrRepositoryProvider).updateDepartment(
            d.departmentId,
            name: nameCtrl.text,
            isActive: isActive,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department updated')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _confirmDeleteDepartment(DepartmentDto d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete department?'),
        content: Text('Delete ${d.name}?'),
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
      await ref.read(hrRepositoryProvider).deleteDepartment(d.departmentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department deleted')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _openCreateDesignation(DepartmentDto d) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isActive = true;
    int? defaultAppRoleId;

    final uniqueAppRolesById = <int, RoleDto>{};
    for (final r in _appRoles) {
      uniqueAppRolesById[r.roleId] = r;
    }
    final appRoles = uniqueAppRolesById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text('Add Designation • ${d.name}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  key: ValueKey(defaultAppRoleId),
                  initialValue: defaultAppRoleId,
                  decoration: const InputDecoration(
                    labelText: 'Default app role (optional)',
                    prefixIcon: Icon(Icons.security_rounded),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No default'),
                    ),
                    ...appRoles.map(
                      (r) => DropdownMenuItem<int?>(
                        value: r.roleId,
                        child: Text(r.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setInner(() => defaultAppRoleId = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.work_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  onChanged: (v) => setInner(() => isActive = v),
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(hrRepositoryProvider).createDesignation(
            departmentId: d.departmentId,
            defaultAppRoleId: defaultAppRoleId,
            name: nameCtrl.text,
            description: descCtrl.text.trim().isEmpty ? null : descCtrl.text,
            isActive: isActive,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Designation created')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _openEditDesignation(DesignationDto r) async {
    final nameCtrl = TextEditingController(text: r.name);
    final descCtrl = TextEditingController(text: r.description ?? '');
    bool isActive = r.isActive;
    int? departmentId = r.departmentId;
    int? defaultAppRoleId = r.defaultAppRoleId;

    final uniqueDepartmentsById = <int, DepartmentDto>{};
    for (final d in _departments) {
      uniqueDepartmentsById[d.departmentId] = d;
    }
    final deptItems = uniqueDepartmentsById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final uniqueAppRolesById = <int, RoleDto>{};
    for (final a in _appRoles) {
      uniqueAppRolesById[a.roleId] = a;
    }
    final appRoles = uniqueAppRolesById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Edit Designation'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  key: ValueKey(departmentId),
                  initialValue: departmentId == null ||
                          deptItems.any((d) => d.departmentId == departmentId)
                      ? departmentId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                  items: deptItems
                      .map(
                        (d) => DropdownMenuItem<int?>(
                          value: d.departmentId,
                          child: Text(d.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) => setInner(() => departmentId = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  key: ValueKey(defaultAppRoleId),
                  initialValue: defaultAppRoleId == null ||
                          appRoles.any((r) => r.roleId == defaultAppRoleId)
                      ? defaultAppRoleId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Default app role (optional)',
                    prefixIcon: Icon(Icons.security_rounded),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No default'),
                    ),
                    ...appRoles.map(
                      (r) => DropdownMenuItem<int?>(
                        value: r.roleId,
                        child: Text(r.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setInner(() => defaultAppRoleId = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.work_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  onChanged: (v) => setInner(() => isActive = v),
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    if (departmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a department')),
      );
      return;
    }

    try {
      await ref.read(hrRepositoryProvider).updateDesignation(
            r.designationId,
            departmentId: departmentId,
            defaultAppRoleId: defaultAppRoleId ?? 0,
            name: nameCtrl.text,
            description: descCtrl.text,
            isActive: isActive,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Designation updated')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.message(e))),
      );
    }
  }

  Future<void> _confirmDeleteDesignation(DesignationDto r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete designation?'),
        content: Text('Delete ${r.name}?'),
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
      await ref.read(hrRepositoryProvider).deleteDesignation(r.designationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Designation deleted')),
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
    final uniqueDepartmentsById = <int, DepartmentDto>{};
    for (final d in _departments) {
      uniqueDepartmentsById[d.departmentId] = d;
    }
    final departments = uniqueDepartmentsById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final byDept = <int, List<DesignationDto>>{};
    final unassigned = <DesignationDto>[];
    for (final d in _designations) {
      final depId = d.departmentId;
      if (depId == null) {
        unassigned.add(d);
      } else {
        (byDept[depId] ??= []).add(d);
      }
    }
    for (final list in byDept.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    unassigned.sort((a, b) => a.name.compareTo(b.name));

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
        title: const Text('Departments & Designations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateDepartment,
        tooltip: 'Add Department',
        child: const Icon(Icons.add_rounded),
      ),
      drawer: widget.fromMenu
          ? DashboardSidebar(
              onSelect: (label) => widget.onMenuSelect?.call(context, label),
            )
          : null,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? AppErrorView(error: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final dept in departments)
                        Card(
                          elevation: 0,
                          child: ExpansionTile(
                            leading: Icon(
                              dept.isActive
                                  ? Icons.apartment_rounded
                                  : Icons.apartment_outlined,
                            ),
                            title: Text(dept.name),
                            subtitle:
                                Text(dept.isActive ? 'Active' : 'Inactive'),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                IconButton(
                                  tooltip: 'Add designation',
                                  onPressed: () => _openCreateDesignation(dept),
                                  icon: const Icon(Icons.add_rounded),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') {
                                      _openEditDepartment(dept);
                                    } else if (v == 'delete') {
                                      _confirmDeleteDepartment(dept);
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
                              ],
                            ),
                            children: [
                              ...(byDept[dept.departmentId] ?? const []).map(
                                (r) => ListTile(
                                  leading: Icon(
                                    r.isActive
                                        ? Icons.work_rounded
                                        : Icons.work_outline_rounded,
                                  ),
                                  title: Text(r.name),
                                  subtitle: (r.description ?? '').trim().isEmpty
                                      ? null
                                      : Text(r.description!),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') {
                                        _openEditDesignation(r);
                                      } else if (v == 'delete') {
                                        _confirmDeleteDesignation(r);
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
                                  onTap: () => _openEditDesignation(r),
                                ),
                              ),
                              if ((byDept[dept.departmentId] ?? const [])
                                  .isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 12,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('No designations'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (unassigned.isNotEmpty)
                        Card(
                          elevation: 0,
                          child: ExpansionTile(
                            leading: const Icon(Icons.work_outline_rounded),
                            title: const Text('Unassigned'),
                            subtitle:
                                const Text('Designations without a department'),
                            children: [
                              ...unassigned.map(
                                (r) => ListTile(
                                  leading: Icon(
                                    r.isActive
                                        ? Icons.work_rounded
                                        : Icons.work_outline_rounded,
                                  ),
                                  title: Text(r.name),
                                  subtitle: (r.description ?? '').trim().isEmpty
                                      ? null
                                      : Text(r.description!),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') {
                                        _openEditDesignation(r);
                                      } else if (v == 'delete') {
                                        _confirmDeleteDesignation(r);
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
                                ),
                              ),
                            ],
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
