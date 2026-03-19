import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryMetricCard extends StatelessWidget {
  const SummaryMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.helpText,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? helpText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((helpText ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      helpText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<T?> showSearchPickerDialog<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T item) titleBuilder,
  String Function(T item)? subtitleBuilder,
  String Function(T item)? searchTextBuilder,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) {
      var query = '';
      return StatefulBuilder(
        builder: (context, setState) {
          final filtered = items.where((item) {
            final haystack =
                (searchTextBuilder?.call(item) ?? titleBuilder(item))
                    .toLowerCase();
            return haystack.contains(query.toLowerCase());
          }).toList();
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(() => query = value.trim()),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No matching records'))
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final subtitle = subtitleBuilder?.call(item);
                              return ListTile(
                                title: Text(titleBuilder(item)),
                                subtitle:
                                    subtitle == null || subtitle.trim().isEmpty
                                        ? null
                                        : Text(subtitle),
                                onTap: () => Navigator.of(context).pop(item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    },
  );
}

String formatMoney(double value) => value.toStringAsFixed(2);

String formatQuantity(double value) =>
    value.toStringAsFixed(value % 1 == 0 ? 0 : 3);

String formatShortDate(DateTime? value) {
  if (value == null) return '—';
  return DateFormat('yyyy-MM-dd').format(value.toLocal());
}

String humanizeToken(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return raw;
  return value
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}
