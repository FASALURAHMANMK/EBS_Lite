import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import 'locale_preferences.dart';

class AppDateTime {
  static List<String>? _cachedTimeZoneIds;

  static String formatDate(
    BuildContext context,
    LocalePreferencesState preferences,
    DateTime? value, {
    String fallback = '--',
  }) {
    if (value == null) return fallback;
    final displayValue = toDisplayDateTime(preferences, value);
    return DateFormat.yMMMd(preferences.formatLocaleTag).format(displayValue);
  }

  static String formatDateTime(
    BuildContext context,
    LocalePreferencesState preferences,
    DateTime? value, {
    String fallback = '--',
    bool includeSeconds = false,
    bool includeTimeZone = false,
  }) {
    if (value == null) return fallback;
    final displayValue = toDisplayDateTime(preferences, value);
    final locale = preferences.formatLocaleTag;
    final date = DateFormat.yMMMd(locale).format(displayValue);
    final time = _timeFormatter(
      context,
      locale,
      includeSeconds: includeSeconds,
    ).format(displayValue);
    final suffix =
        includeTimeZone ? ' (${displayTimeZoneLabel(preferences)})' : '';
    return '$date, $time$suffix';
  }

  static String formatMonthYear(
    LocalePreferencesState preferences,
    DateTime? value, {
    String fallback = '--',
  }) {
    if (value == null) return fallback;
    final displayValue = toDisplayDateTime(preferences, value);
    return DateFormat.yMMM(preferences.formatLocaleTag).format(displayValue);
  }

  static String formatFlexibleDate(
    BuildContext context,
    LocalePreferencesState preferences,
    String? raw, {
    String fallback = '--',
    bool includeTime = false,
    bool includeTimeZone = false,
  }) {
    final parsed = tryParseFlexible(raw);
    if (parsed == null) {
      return fallback;
    }
    if (includeTime) {
      return formatDateTime(
        context,
        preferences,
        parsed,
        fallback: fallback,
        includeTimeZone: includeTimeZone,
      );
    }
    return formatDate(context, preferences, parsed, fallback: fallback);
  }

  static DateTime toDisplayDateTime(
    LocalePreferencesState preferences,
    DateTime value,
  ) {
    final zoneId = preferences.timeZoneId?.trim();
    if (zoneId == null || zoneId.isEmpty) {
      return value.toLocal();
    }

    try {
      final location = tz.getLocation(zoneId);
      final utcValue = value.isUtc ? value : value.toUtc();
      return tz.TZDateTime.from(utcValue, location);
    } catch (_) {
      return value.toLocal();
    }
  }

  static String displayTimeZoneLabel(LocalePreferencesState preferences) {
    final zoneId = preferences.timeZoneId?.trim();
    if (zoneId == null || zoneId.isEmpty) {
      final deviceLabel = DateTime.now().timeZoneName.trim();
      return deviceLabel.isEmpty ? 'Device time zone' : deviceLabel;
    }
    return zoneId.replaceAll('_', ' ');
  }

  static List<String> availableTimeZoneIds() {
    final cached = _cachedTimeZoneIds;
    if (cached != null) {
      return cached;
    }

    final ids = tz.timeZoneDatabase.locations.keys.toList()..sort();
    _cachedTimeZoneIds = ids;
    return ids;
  }

  static DateTime? tryParseFlexible(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final direct = DateTime.tryParse(trimmed);
    if (direct != null) {
      return direct;
    }

    const layouts = <String>[
      'yyyy-MM-dd',
      'yyyy-MM',
    ];

    for (final layout in layouts) {
      try {
        return DateFormat(layout).parseStrict(trimmed);
      } catch (_) {
        // Try the next layout.
      }
    }
    return null;
  }

  static DateFormat _timeFormatter(
    BuildContext context,
    String locale, {
    required bool includeSeconds,
  }) {
    final use24Hour =
        MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false;
    if (use24Hour) {
      return includeSeconds ? DateFormat.Hms(locale) : DateFormat.Hm(locale);
    }
    return includeSeconds ? DateFormat.jms(locale) : DateFormat.jm(locale);
  }
}
