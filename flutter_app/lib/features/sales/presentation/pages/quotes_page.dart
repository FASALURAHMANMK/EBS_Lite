import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../data/sales_repository.dart';
import 'quote_detail_page.dart';
import 'quote_form_page.dart';

class QuotesPage extends ConsumerStatefulWidget {
  const QuotesPage({super.key});

  @override
  ConsumerState<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends ConsumerState<QuotesPage> {
  bool _loading = true;
  Object? _error;
  List<Map<String, dynamic>> _quotes = const [];
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(salesRepositoryProvider);
      final list = await repo.getQuotes(
        status: _statusFilter == 'ALL' ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() => _quotes = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({int? quoteId}) async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => QuoteFormPage(quoteId: quoteId)),
    );
    if (res == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final localePrefs = ref.watch(localePreferencesProvider);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Quotes'),
        actions: [
          IconButton(
            tooltip: 'New Quote',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => _openForm(),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text('Status:'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _statusFilter,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('All')),
                          DropdownMenuItem(
                              value: 'DRAFT', child: Text('Draft')),
                          DropdownMenuItem(value: 'SENT', child: Text('Sent')),
                          DropdownMenuItem(
                              value: 'ACCEPTED', child: Text('Accepted')),
                          DropdownMenuItem(
                              value: 'CONVERTED', child: Text('Converted')),
                        ],
                        onChanged: (value) {
                          if (value == null || value == _statusFilter) return;
                          setState(() => _statusFilter = value);
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) => _load());
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? AppErrorView(error: _error!, onRetry: _load)
                  : _quotes.isEmpty
                      ? const AppEmptyView(
                          title: 'No quotes',
                          message:
                              'Quotes will appear here once they are created.',
                          icon: Icons.request_quote_outlined,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _quotes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final q = _quotes[index];
                            final number = q['quote_number']?.toString() ?? '';
                            final status = q['status']?.toString() ?? 'DRAFT';
                            final total =
                                ((q['total_amount'] as num?)?.toDouble() ?? 0.0)
                                    .toStringAsFixed(2);
                            final customerName =
                                (q['customer'] is Map<String, dynamic>)
                                    ? (q['customer']['name']?.toString() ?? '')
                                    : '';
                            final dateStr = AppDateTime.formatFlexibleDate(
                              context,
                              localePrefs,
                              q['quote_date']?.toString(),
                              fallback: q['quote_date']?.toString() ?? '',
                            );

                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading:
                                    const Icon(Icons.request_quote_rounded),
                                title: Text(number.isEmpty ? 'Quote' : number),
                                subtitle: Text([
                                  if (customerName.isNotEmpty) customerName,
                                  if (dateStr.isNotEmpty) dateStr,
                                  status,
                                ].where((e) => e.isNotEmpty).join(' - ')),
                                trailing: Text(total,
                                    style: theme.textTheme.titleMedium),
                                onTap: () {
                                  final id = q['quote_id'] as int?;
                                  if (id != null) {
                                    Navigator.of(context)
                                        .push(MaterialPageRoute(
                                            builder: (_) =>
                                                QuoteDetailPage(quoteId: id)))
                                        .then((_) => _load());
                                  }
                                },
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
