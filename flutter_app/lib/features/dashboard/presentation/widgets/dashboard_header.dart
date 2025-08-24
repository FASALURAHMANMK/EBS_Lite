// lib/dashboard/presentation/dashboard_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardHeader extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const DashboardHeader({
    super.key,
    this.companyName = 'Company',
    this.companyIcon,
    this.isOnline = true,
    this.onToggleTheme,
    this.onHelp,
    this.onLogout,
    this.locations = const ['Location 1', 'Location 2'],
    this.selectedLocation,
    this.onLocationChanged,
    this.languages = const ['English', 'Spanish'],
    this.selectedLanguage,
    this.onLanguageChanged,
  });

  /// Branding
  final String companyName;
  final IconData? companyIcon;

  /// Realtime/Sync status
  final bool isOnline;

  /// Callbacks
  final VoidCallback? onToggleTheme;
  final VoidCallback? onHelp;
  final VoidCallback? onLogout;

  /// Location selector
  final List<String> locations;
  final String? selectedLocation;
  final ValueChanged<String>? onLocationChanged;

  /// Language selector
  final List<String> languages;
  final String? selectedLanguage;
  final ValueChanged<String>? onLanguageChanged;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  ConsumerState<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends ConsumerState<DashboardHeader> {
  late String _location;
  late String _language;

  @override
  void initState() {
    super.initState();
    _location = widget.selectedLocation ??
        (widget.locations.isNotEmpty ? widget.locations.first : 'Default');
    _language = widget.selectedLanguage ??
        (widget.languages.isNotEmpty ? widget.languages.first : 'English');
  }

  void _setLocation(String value) {
    setState(() => _location = value);
    widget.onLocationChanged?.call(value);
  }

  void _setLanguage(String value) {
    setState(() => _language = value);
    widget.onLanguageChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 680;

    final statusColor =
        widget.isOnline ? Colors.green : theme.colorScheme.error;
    final statusIcon =
        widget.isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded;
    final brandIcon = widget.companyIcon ?? Icons.apartment_rounded;

    return AppBar(
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: true,
      titleSpacing: isCompact ? 0 : 8,
      title: Row(
        children: [
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
            child: Icon(brandIcon, color: theme.colorScheme.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            widget.companyName,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 12),
          if (!isCompact) ...[
            _LocationSelector(
              value: _location,
              items: widget.locations,
              onChanged: _setLocation,
            ),
          ],
        ],
      ),
      actions: [
        if (isCompact)
          _CompactMenus(
            locationValue: _location,
            languageValue: _language,
            locations: widget.locations,
            languages: widget.languages,
            onSelectLocation: _setLocation,
            onSelectLanguage: _setLanguage,
          )
        else ...[
          // Online/Sync status chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Tooltip(
              message: widget.isOnline
                  ? 'All changes are synced'
                  : 'Offline — changes will sync later',
              child: Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: statusColor.withOpacity(0.12),
                side: BorderSide(color: statusColor.withOpacity(0.24)),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                avatar: Icon(statusIcon, size: 18, color: statusColor),
                label: Text(
                  widget.isOnline ? 'Online' : 'Offline',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: statusColor, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          // Language selector
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _LanguageSelector(
              value: _language,
              items: widget.languages,
              onChanged: _setLanguage,
            ),
          ),
        ],
        // Theme toggle
        IconButton(
          tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
          icon:
              Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
          onPressed: widget.onToggleTheme,
        ),
        // Help
        IconButton(
          tooltip: 'Help & support',
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: widget.onHelp,
        ),
        // Profile / Logout overflow
        PopupMenuButton<_HeaderMenu>(
          tooltip: 'Account',
          icon: const Icon(Icons.account_circle_rounded),
          onSelected: (v) {
            if (v == _HeaderMenu.logout) {
              widget.onLogout?.call();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _HeaderMenu.profile,
              child: ListTile(
                leading: Icon(Icons.person_rounded),
                title: Text('Profile'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: _HeaderMenu.logout,
              child: ListTile(
                leading: Icon(Icons.logout_rounded),
                title: Text('Logout'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1),
      ),
    );
  }
}

enum _HeaderMenu { profile, logout }

/// Wide-layout dropdown for Locations.
class _LocationSelector extends StatelessWidget {
  const _LocationSelector({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value)
              ? value
              : (items.isNotEmpty ? items.first : null),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          alignment: Alignment.centerLeft,
          borderRadius: BorderRadius.circular(12),
          items: items
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

/// Wide-layout dropdown for Languages.
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value)
              ? value
              : (items.isNotEmpty ? items.first : null),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          alignment: Alignment.centerLeft,
          borderRadius: BorderRadius.circular(12),
          items: items
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

/// Compact overflow menus for small widths.
class _CompactMenus extends StatelessWidget {
  const _CompactMenus({
    required this.locationValue,
    required this.languageValue,
    required this.locations,
    required this.languages,
    required this.onSelectLocation,
    required this.onSelectLanguage,
  });

  final String locationValue;
  final String languageValue;
  final List<String> locations;
  final List<String> languages;
  final ValueChanged<String> onSelectLocation;
  final ValueChanged<String> onSelectLanguage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        PopupMenuButton<String>(
          tooltip: 'Switch location',
          icon: const Icon(Icons.place_rounded),
          initialValue: locationValue,
          onSelected: onSelectLocation,
          itemBuilder: (context) => locations
              .map((e) => PopupMenuItem<String>(
                    value: e,
                    child: Row(
                      children: [
                        Icon(
                          e == locationValue
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: e == locationValue
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: Text(e)),
                      ],
                    ),
                  ))
              .toList(),
        ),
        PopupMenuButton<String>(
          tooltip: 'Language',
          icon: const Icon(Icons.language_rounded),
          initialValue: languageValue,
          onSelected: onSelectLanguage,
          itemBuilder: (context) => languages
              .map((e) => PopupMenuItem<String>(
                    value: e,
                    child: Row(
                      children: [
                        Icon(
                          e == languageValue
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: e == languageValue
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: Text(e)),
                      ],
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
