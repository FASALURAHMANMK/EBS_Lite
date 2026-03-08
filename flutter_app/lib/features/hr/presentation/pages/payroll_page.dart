import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/hr_repository.dart';
import '../../data/models.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_error_view.dart';
import 'payslip_page.dart';

class PayrollPage extends ConsumerStatefulWidget {
  const PayrollPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends ConsumerState<PayrollPage> {
  bool _loading = true;
  Object? _error;
  List<PayrollDto> _payrolls = const [];

  final TextEditingController _employeeIdCtrl = TextEditingController();
  final TextEditingController _monthCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _employeeIdCtrl.dispose();
    _monthCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(hrRepositoryProvider);
      final id = int.tryParse(_employeeIdCtrl.text.trim());
      final month = _monthCtrl.text.trim().isEmpty ? null : _monthCtrl.text;
      final list = await repo.getPayrolls(employeeId: id, month: month);
      if (!mounted) return;
      setState(() => _payrolls = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Select any date in month',
    );
    if (picked == null) return;
    setState(() => _monthCtrl.text = DateFormat('yyyy-MM').format(picked));
    await _load();
  }

  Future<void> _createPayrollDialog() async {
    String month = DateFormat('yyyy-MM').format(DateTime.now());
    final emp = TextEditingController();
    final basic = TextEditingController();
    final allowances = TextEditingController(text: '0');
    final deductions = TextEditingController(text: '0');
    bool autoCalc = true;
    PayrollCalculationDto? calc;
    bool calcLoading = false;

    Future<void> runCalc(
        BuildContext dialogContext, StateSetter setInner) async {
      final messenger = ScaffoldMessenger.of(context);
      final empId = int.tryParse(emp.text.trim());
      final baseMonthly = double.tryParse(basic.text.trim());
      if (empId == null || empId <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Enter a valid employee id first')),
        );
        return;
      }
      setInner(() => calcLoading = true);
      PayrollCalculationDto? res;
      Object? err;
      try {
        res = await ref.read(hrRepositoryProvider).calculatePayroll(
              employeeId: empId,
              month: month,
              baseMonthlySalary: baseMonthly,
            );
      } catch (e) {
        err = e;
      }

      if (!mounted) return;
      if (!dialogContext.mounted) return;

      setInner(() {
        calcLoading = false;
        if (res != null) calc = res;
      });

      if (err != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(ErrorHandler.message(err))),
        );
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setInner) => AlertDialog(
          title: const Text('Generate Payroll'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: month),
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Month (YYYY-MM)',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setInner(
                          () => month = DateFormat('yyyy-MM').format(picked));
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: basic,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        autoCalc ? 'Base monthly salary' : 'Basic Salary',
                    prefixIcon: const Icon(Icons.payments_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: autoCalc,
                  onChanged: (v) => setInner(() {
                    autoCalc = v;
                    calc = null;
                  }),
                  title: const Text('Auto-calculate (attendance + leaves)'),
                ),
                if (autoCalc) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: calcLoading
                          ? null
                          : () => runCalc(dialogContext, setInner),
                      icon: calcLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calculate_rounded),
                      label: const Text('Calculate'),
                    ),
                  ),
                  if (calc != null) ...[
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Working days: ${calc!.workingDays}\n'
                          'Payable days: ${calc!.payableDays.toStringAsFixed(1)}\n'
                          'Present: ${calc!.presentDays.toStringAsFixed(1)}\n'
                          'Approved leave: ${calc!.approvedLeaveDays.toStringAsFixed(1)}\n'
                          'Unpaid absence: ${calc!.unpaidAbsenceDays.toStringAsFixed(1)}\n'
                          'Prorated basic: ${calc!.proratedBasicSalary.toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: allowances,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Allowances',
                    prefixIcon: Icon(Icons.add_circle_outline_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: deductions,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Deductions',
                    prefixIcon: Icon(Icons.remove_circle_outline_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Generate')),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (ok != true) return;
    final empId = int.tryParse(emp.text.trim());
    final basicVal = double.tryParse(basic.text.trim());
    final allowanceVal = double.tryParse(allowances.text.trim()) ?? 0;
    final deductionVal = double.tryParse(deductions.text.trim()) ?? 0;

    if (empId == null || empId <= 0 || basicVal == null || basicVal < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid employee and base salary')),
      );
      return;
    }

    try {
      await ref.read(hrRepositoryProvider).createPayroll(
            employeeId: empId,
            month: month,
            basicSalary: basicVal,
            allowances: allowanceVal,
            deductions: deductionVal,
            autoCalculate: autoCalc,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payroll generated')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  Future<void> _markPaid(PayrollDto payroll) async {
    try {
      await ref.read(hrRepositoryProvider).markPaid(payroll.payrollId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payroll marked as paid')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
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
            : null,
        title: const Text('Payroll'),
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
        onPressed: _createPayrollDialog,
        tooltip: 'Generate Payroll',
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
                              controller: _employeeIdCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Employee ID (optional)',
                                prefixIcon: Icon(Icons.badge_rounded),
                              ),
                              onChanged: (_) => _load(),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _monthCtrl,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Month (YYYY-MM)',
                                      prefixIcon:
                                          Icon(Icons.calendar_today_rounded),
                                    ),
                                    onTap: _pickMonth,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () {
                                    _monthCtrl.clear();
                                    _load();
                                  },
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _payrolls.isEmpty
                            ? const Center(child: Text('No payrolls found'))
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _payrolls.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final p = _payrolls[i];
                                  return Card(
                                    elevation: 0,
                                    child: ListTile(
                                      leading:
                                          const Icon(Icons.payments_rounded),
                                      title: Text(
                                          'Employee #${p.employeeId} • ${p.netSalary.toStringAsFixed(2)}'),
                                      subtitle: Text(
                                          '${df.format(p.payPeriodStart.toLocal())} → ${df.format(p.payPeriodEnd.toLocal())}\nStatus: ${p.status}'),
                                      isThreeLine: true,
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'payslip') {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => PayslipPage(
                                                  payrollId: p.payrollId,
                                                ),
                                              ),
                                            );
                                          } else if (v == 'paid') {
                                            _markPaid(p);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'payslip',
                                            child: Text('View payslip'),
                                          ),
                                          if (p.status.toUpperCase() != 'PAID')
                                            const PopupMenuItem(
                                              value: 'paid',
                                              child: Text('Mark paid'),
                                            ),
                                        ],
                                      ),
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
