import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/app_date_time.dart';
import '../../data/hr_repository.dart';
import '../../data/models.dart';
import '../../../dashboard/presentation/widgets/dashboard_sidebar.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/locale_preferences.dart';

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loadingRecords = false;
  bool _loadingHolidays = false;
  String? _recordsError;
  String? _holidaysError;
  List<AttendanceDto> _records = const [];
  List<HolidayDto> _holidays = const [];

  AttendanceDto? _lastCheck;
  LeaveDto? _lastLeave;

  final TextEditingController _employeeIdCtrl = TextEditingController();
  final TextEditingController _recordsEmployeeIdCtrl = TextEditingController();
  final TextEditingController _leaveEmployeeIdCtrl = TextEditingController();
  final TextEditingController _leaveReasonCtrl = TextEditingController();

  DateTime? _recordsFrom;
  DateTime? _recordsTo;
  DateTime? _leaveStart;
  DateTime? _leaveEnd;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRecords();
    _loadHolidays();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _employeeIdCtrl.dispose();
    _recordsEmployeeIdCtrl.dispose();
    _leaveEmployeeIdCtrl.dispose();
    _leaveReasonCtrl.dispose();
    super.dispose();
  }

  int? _parseEmployeeId(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _loadRecords() async {
    setState(() {
      _loadingRecords = true;
      _recordsError = null;
    });
    try {
      final repo = ref.read(hrRepositoryProvider);
      final id = _parseEmployeeId(_recordsEmployeeIdCtrl);
      final list = await repo.getRecords(
        employeeId: id,
        startDate: _recordsFrom,
        endDate: _recordsTo,
      );
      if (!mounted) return;
      setState(() => _records = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _recordsError = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _loadingRecords = false);
    }
  }

  Future<void> _loadHolidays() async {
    setState(() {
      _loadingHolidays = true;
      _holidaysError = null;
    });
    try {
      final repo = ref.read(hrRepositoryProvider);
      final list = await repo.getHolidays();
      if (!mounted) return;
      setState(() => _holidays = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _holidaysError = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _loadingHolidays = false);
    }
  }

  Future<void> _checkIn() async {
    final id = _parseEmployeeId(_employeeIdCtrl);
    if (id == null || id <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter employee ID')));
      return;
    }
    try {
      final att = await ref.read(hrRepositoryProvider).checkIn(id);
      if (!mounted) return;
      setState(() => _lastCheck = att);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Check-in recorded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  Future<void> _checkOut() async {
    final id = _parseEmployeeId(_employeeIdCtrl);
    if (id == null || id <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter employee ID')));
      return;
    }
    try {
      final att = await ref.read(hrRepositoryProvider).checkOut(id);
      if (!mounted) return;
      setState(() => _lastCheck = att);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Check-out recorded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  Future<void> _applyLeave() async {
    final id = _parseEmployeeId(_leaveEmployeeIdCtrl);
    if (id == null || id <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter employee ID')));
      return;
    }
    if (_leaveStart == null || _leaveEnd == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select leave dates')));
      return;
    }
    final reason = _leaveReasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a reason')));
      return;
    }
    try {
      final leave = await ref.read(hrRepositoryProvider).applyLeave(
            employeeId: id,
            startDate: _leaveStart!,
            endDate: _leaveEnd!,
            reason: reason,
          );
      if (!mounted) return;
      setState(() => _lastLeave = leave);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Leave applied')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from ? _recordsFrom : _recordsTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _recordsFrom = picked;
      } else {
        _recordsTo = picked;
      }
    });
    await _loadRecords();
  }

  Future<void> _pickLeaveDate({required bool start}) async {
    final initial = start ? _leaveStart : _leaveEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _leaveStart = picked;
      } else {
        _leaveEnd = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
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
        title: const Text('Attendance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Check In/Out'),
            Tab(text: 'Records'),
            Tab(text: 'Leave'),
            Tab(text: 'Holidays'),
          ],
        ),
      ),
      drawer: widget.fromMenu
          ? DashboardSidebar(
              onSelect: (label) => widget.onMenuSelect?.call(context, label),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCheckInOut(),
          _buildRecords(),
          _buildLeave(),
          _buildHolidays(),
        ],
      ),
    );

    if (!widget.fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }

  Widget _buildCheckInOut() {
    final localePrefs = ref.watch(localePreferencesProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _employeeIdCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Employee ID',
            prefixIcon: Icon(Icons.badge_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _checkIn,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Check In'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _checkOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Check Out'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _lastCheck == null
                ? const Text('No recent check-in/out recorded.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Employee #${_lastCheck!.employeeId}',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                        'Check-in: ${AppDateTime.formatDateTime(context, localePrefs, _lastCheck!.checkIn)}',
                      ),
                      Text(
                        'Check-out: ${_lastCheck!.checkOut == null ? '—' : AppDateTime.formatDateTime(context, localePrefs, _lastCheck!.checkOut)}',
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecords() {
    final localePrefs = ref.watch(localePreferencesProvider);
    String dateLabel(DateTime? d) =>
        d == null ? 'Any' : AppDateTime.formatDate(context, localePrefs, d);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _recordsEmployeeIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Employee ID (optional)',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(from: true),
                    icon: const Icon(Icons.event_rounded),
                    label: Text('From: ${dateLabel(_recordsFrom)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(from: false),
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text('To: ${dateLabel(_recordsTo)}'),
                  ),
                  FilledButton(
                    onPressed: _loadRecords,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingRecords
              ? const Center(child: CircularProgressIndicator())
              : _recordsError != null
                  ? Center(child: Text(_recordsError!))
                  : _records.isEmpty
                      ? const Center(child: Text('No records found'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _records.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final r = _records[i];
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading: const Icon(Icons.access_time_rounded),
                                title: Text('Employee #${r.employeeId}'),
                                subtitle: Text(
                                  'In: ${AppDateTime.formatDateTime(context, localePrefs, r.checkIn)}\nOut: ${r.checkOut == null ? '—' : AppDateTime.formatDateTime(context, localePrefs, r.checkOut)}',
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildLeave() {
    final localePrefs = ref.watch(localePreferencesProvider);
    String dateLabel(DateTime? d) =>
        d == null ? 'Select' : AppDateTime.formatDate(context, localePrefs, d);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _leaveEmployeeIdCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Employee ID',
            prefixIcon: Icon(Icons.badge_rounded),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickLeaveDate(start: true),
          icon: const Icon(Icons.event_rounded),
          label: Text('Start: ${dateLabel(_leaveStart)}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _pickLeaveDate(start: false),
          icon: const Icon(Icons.event_available_rounded),
          label: Text('End: ${dateLabel(_leaveEnd)}'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _leaveReasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _applyLeave,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Submit Leave Request'),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _lastLeave == null
                ? const Text('No leave submitted yet.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Leave #${_lastLeave!.leaveId}',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text('Employee: ${_lastLeave!.employeeId}'),
                      Text(
                          'Dates: ${formatShortDate(_lastLeave!.startDate)} → ${formatShortDate(_lastLeave!.endDate)}'),
                      Text('Status: ${_lastLeave!.status}'),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHolidays() {
    final localePrefs = ref.watch(localePreferencesProvider);
    return _loadingHolidays
        ? const Center(child: CircularProgressIndicator())
        : _holidaysError != null
            ? Center(child: Text(_holidaysError!))
            : _holidays.isEmpty
                ? const Center(child: Text('No holidays configured'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _holidays.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final h = _holidays[i];
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today_rounded),
                          title: Text(h.name),
                          subtitle: Text(
                            AppDateTime.formatDate(
                                context, localePrefs, h.date),
                          ),
                        ),
                      );
                    },
                  );
  }
}
