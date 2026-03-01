import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/hr_repository.dart';
import '../../data/models.dart';
import '../../../../core/error_handler.dart';

class PayslipPage extends ConsumerStatefulWidget {
  const PayslipPage({super.key, required this.payrollId});

  final int payrollId;

  @override
  ConsumerState<PayslipPage> createState() => _PayslipPageState();
}

class _PayslipPageState extends ConsumerState<PayslipPage> {
  bool _loading = true;
  String? _error;
  PayslipDto? _payslip;

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
      final data = await repo.getPayslip(widget.payrollId);
      if (!mounted) return;
      setState(() => _payslip = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    return Scaffold(
      appBar: AppBar(
        title: Text('Payslip #${widget.payrollId}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _payslip == null
                    ? const Center(child: Text('Payslip not available'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Employee #${_payslip!.payroll.employeeId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  const SizedBox(height: 6),
                                  Text(
                                      'Period: ${df.format(_payslip!.payroll.payPeriodStart.toLocal())} → ${df.format(_payslip!.payroll.payPeriodEnd.toLocal())}'),
                                  Text(
                                      'Basic: ${_payslip!.payroll.basicSalary.toStringAsFixed(2)}'),
                                  Text(
                                      'Gross: ${_payslip!.payroll.grossSalary.toStringAsFixed(2)}'),
                                  Text(
                                      'Deductions: ${_payslip!.payroll.totalDeductions.toStringAsFixed(2)}'),
                                  Text(
                                      'Net: ${_payslip!.payroll.netSalary.toStringAsFixed(2)}'),
                                  Text('Status: ${_payslip!.payroll.status}'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _sectionTitle('Components'),
                          _payslip!.components.isEmpty
                              ? const _EmptyNote(text: 'No components')
                              : _listCards(
                                  _payslip!.components
                                      .map((c) =>
                                          '${c.type} • ${c.amount.toStringAsFixed(2)}')
                                      .toList(),
                                ),
                          const SizedBox(height: 12),
                          _sectionTitle('Advances'),
                          _payslip!.advances.isEmpty
                              ? const _EmptyNote(text: 'No advances')
                              : _listCards(
                                  _payslip!.advances
                                      .map((a) =>
                                          '${df.format(a.date.toLocal())} • ${a.amount.toStringAsFixed(2)}')
                                      .toList(),
                                ),
                          const SizedBox(height: 12),
                          _sectionTitle('Deductions'),
                          _payslip!.deductions.isEmpty
                              ? const _EmptyNote(text: 'No deductions')
                              : _listCards(
                                  _payslip!.deductions
                                      .map((d) =>
                                          '${d.type} • ${d.amount.toStringAsFixed(2)} • ${df.format(d.date.toLocal())}')
                                      .toList(),
                                ),
                          const SizedBox(height: 12),
                          Card(
                            elevation: 0,
                            child: ListTile(
                              leading: const Icon(Icons.paid_rounded),
                              title: const Text('Net Pay'),
                              trailing: Text(
                                _payslip!.netPay.toStringAsFixed(2),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  Widget _listCards(List<String> lines) {
    return Column(
      children: lines
          .map(
            (line) => Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.chevron_right_rounded),
                title: Text(line),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text),
      ),
    );
  }
}
