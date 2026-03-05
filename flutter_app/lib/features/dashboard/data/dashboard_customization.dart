import 'dart:convert';

class DashboardCustomization {
  const DashboardCustomization({
    required this.shortcutActionIds,
    required this.quickActionId,
  });

  static const Object _noChange = Object();

  static const String preferenceKey = 'dashboard_customization_v1';

  static const DashboardCustomization defaults = DashboardCustomization(
    shortcutActionIds: [
      'new_sale',
      'products',
      'customers',
      'cash_register',
    ],
    quickActionId: 'new_sale',
  );

  final List<String> shortcutActionIds;
  final String? quickActionId;

  DashboardCustomization copyWith({
    List<String>? shortcutActionIds,
    Object? quickActionId = _noChange,
  }) {
    return DashboardCustomization(
      shortcutActionIds: shortcutActionIds ?? this.shortcutActionIds,
      quickActionId: quickActionId == _noChange
          ? this.quickActionId
          : quickActionId as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'shortcuts': shortcutActionIds,
        'quick_action': quickActionId,
      };

  static DashboardCustomization fromJson(Map<String, dynamic> json) {
    final shortcutsRaw = json['shortcuts'];
    final shortcuts = shortcutsRaw is List
        ? shortcutsRaw.map((e) => e.toString()).toList()
        : <String>[];
    final quick = json['quick_action'];
    return DashboardCustomization(
      shortcutActionIds: shortcuts,
      quickActionId: quick?.toString(),
    );
  }

  static DashboardCustomization? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return fromJson(decoded);
      if (decoded is Map) {
        return fromJson(decoded.map((k, v) => MapEntry(k.toString(), v)));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}
