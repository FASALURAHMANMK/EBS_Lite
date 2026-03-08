import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hr_repository.dart';
import '../../data/models.dart';
import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_error_view.dart';

class DepartmentsPage extends ConsumerStatefulWidget {
  const DepartmentsPage({super.key});

  @override
  ConsumerState<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends ConsumerState<DepartmentsPage> {
  bool _loading = true;
  Object? _error;
  List<DepartmentDto> _departments = const [];

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(hrRepositoryProvider).getDepartments();
      if (!mounted) return;
      setState(() => _departments = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
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

  Future<void> _openEdit(DepartmentDto d) async {
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

  Future<void> _confirmDelete(DepartmentDto d) async {
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

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _departments
        : _departments
            .where((d) => d.name.toLowerCase().contains(query))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
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
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Search',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No departments found'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final d = filtered[i];
                                  return Card(
                                    elevation: 0,
                                    child: ListTile(
                                      leading: Icon(
                                        d.isActive
                                            ? Icons.apartment_rounded
                                            : Icons.apartment_outlined,
                                      ),
                                      title: Text(d.name),
                                      subtitle: Text(
                                        d.isActive ? 'Active' : 'Inactive',
                                      ),
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'edit') {
                                            _openEdit(d);
                                          } else if (v == 'delete') {
                                            _confirmDelete(d);
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
                                      onTap: () => _openEdit(d),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
