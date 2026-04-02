import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../core/region_options.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';

class LanguageRegionSettingsPage extends ConsumerWidget {
  const LanguageRegionSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(localePreferencesProvider);
    final languageOptions = [
      DropdownMenuItem<Locale>(
        value: const Locale('en'),
        child: Text(l10n.languageEnglish),
      ),
      DropdownMenuItem<Locale>(
        value: const Locale('ar'),
        child: Text(l10n.languageArabic),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageSectionTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.uiLanguageLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.language_rounded),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Locale>(
                isExpanded: true,
                value: prefs.uiLocale,
                items: languageOptions,
                onChanged: (value) {
                  if (value == null) return;
                  ref
                      .read(localePreferencesProvider.notifier)
                      .setUiLocale(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.receiptLanguageLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.receipt_long_rounded),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Locale>(
                isExpanded: true,
                value: prefs.receiptLocale,
                items: languageOptions,
                onChanged: (value) {
                  if (value == null) return;
                  ref
                      .read(localePreferencesProvider.notifier)
                      .setReceiptLocale(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Country / Region',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.public_rounded),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: prefs.countryCode,
                items: supportedCountryOptions
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.code,
                        child: Text('${item.name} (${item.code})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  ref.read(localePreferencesProvider.notifier).setCountryCode(
                        value,
                      );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Time zone'),
              subtitle: Text(AppDateTime.displayTimeZoneLabel(prefs)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final selected = await showDialog<String?>(
                  context: context,
                  builder: (_) => _TimeZonePickerDialog(
                    selectedTimeZoneId: prefs.timeZoneId,
                  ),
                );
                if (selected == null) {
                  return;
                }
                final nextTimeZoneId =
                    selected == _TimeZonePickerDialogState.deviceTimeZoneValue
                        ? null
                        : selected;
                await ref
                    .read(localePreferencesProvider.notifier)
                    .setTimeZoneId(nextTimeZoneId);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeZonePickerDialog extends StatefulWidget {
  const _TimeZonePickerDialog({
    required this.selectedTimeZoneId,
  });

  final String? selectedTimeZoneId;

  @override
  State<_TimeZonePickerDialog> createState() => _TimeZonePickerDialogState();
}

class _TimeZonePickerDialogState extends State<_TimeZonePickerDialog> {
  static const deviceTimeZoneValue = '__device_time_zone__';

  final TextEditingController _searchController = TextEditingController();
  late final List<String> _allTimeZones;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _allTimeZones = AppDateTime.availableTimeZoneIds();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _allTimeZones
        .where((item) => item.toLowerCase().contains(_query))
        .toList(growable: false);

    return AppSelectionDialog(
      title: 'Select time zone',
      searchField: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Search time zone',
          prefixIcon: Icon(Icons.search_rounded),
          border: OutlineInputBorder(),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              widget.selectedTimeZoneId == null
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
            ),
            title: const Text('Device time zone'),
            subtitle: Text(
              DateTime.now().timeZoneName.trim().isEmpty
                  ? 'Use the operating system time zone'
                  : DateTime.now().timeZoneName,
            ),
            onTap: () => Navigator.of(context).pop(deviceTimeZoneValue),
          ),
          const Divider(height: 1),
          for (final item in visible)
            ListTile(
              leading: Icon(
                widget.selectedTimeZoneId == item
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
              ),
              title: Text(item.replaceAll('_', ' ')),
              onTap: () => Navigator.of(context).pop(item),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(widget.selectedTimeZoneId),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
