import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api_client.dart';

const _printersKey = 'printers';

class PrinterDevice {
  final String id;
  final String name;
  final String kind; // 'thermal_80' | 'thermal_58' | 'a4' | 'a5'
  final String connectionType; // 'network' | 'bluetooth' | 'usb' | 'system'
  final String? host; // network
  final int? port; // network
  final String? btAddress; // bluetooth
  final String? btName; // bluetooth
  final int? usbVendorId; // usb
  final int? usbProductId; // usb
  final bool isDefault;

  const PrinterDevice({
    required this.id,
    required this.name,
    required this.kind,
    required this.connectionType,
    this.host,
    this.port,
    this.btAddress,
    this.btName,
    this.usbVendorId,
    this.usbProductId,
    this.isDefault = false,
  });

  PrinterDevice copyWith({
    String? id,
    String? name,
    String? kind,
    String? connectionType,
    String? host,
    int? port,
    String? btAddress,
    String? btName,
    int? usbVendorId,
    int? usbProductId,
    bool? isDefault,
  }) => PrinterDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        connectionType: connectionType ?? this.connectionType,
        host: host ?? this.host,
        port: port ?? this.port,
        btAddress: btAddress ?? this.btAddress,
        btName: btName ?? this.btName,
        usbVendorId: usbVendorId ?? this.usbVendorId,
        usbProductId: usbProductId ?? this.usbProductId,
        isDefault: isDefault ?? this.isDefault,
      );

  factory PrinterDevice.fromJson(Map<String, dynamic> json) => PrinterDevice(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Printer',
        kind: json['kind'] as String? ?? 'a4',
        connectionType: json['connection_type'] as String? ?? 'system',
        host: json['host'] as String?,
        port: (json['port'] as num?)?.toInt(),
        btAddress: json['bt_address'] as String?,
        btName: json['bt_name'] as String?,
        usbVendorId: (json['usb_vendor_id'] as num?)?.toInt(),
        usbProductId: (json['usb_product_id'] as num?)?.toInt(),
        isDefault: json['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'connection_type': connectionType,
        if (host != null) 'host': host,
        if (port != null) 'port': port,
        if (btAddress != null) 'bt_address': btAddress,
        if (btName != null) 'bt_name': btName,
        if (usbVendorId != null) 'usb_vendor_id': usbVendorId,
        if (usbProductId != null) 'usb_product_id': usbProductId,
        'is_default': isDefault,
      };
}

class PrinterSettingsRepository {
  PrinterSettingsRepository(this._ref);
  final Ref _ref;
  final _uuid = const Uuid();

  Future<List<PrinterDevice>> loadAll() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final str = prefs.getString(_printersKey);
    if (str == null || str.isEmpty) return [];
    try {
      final list = (jsonDecode(str) as List<dynamic>).cast<Map<String, dynamic>>();
      return list.map(PrinterDevice.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<PrinterDevice> printers) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString(_printersKey, jsonEncode(printers.map((e) => e.toJson()).toList()));
  }

  Future<PrinterDevice> add(PrinterDevice device) async {
    final list = await loadAll();
    final withId = device.id.isEmpty ? device.copyWith(id: _uuid.v4()) : device;
    // ensure only one default
    List<PrinterDevice> next;
    if (withId.isDefault) {
      next = list.map((p) => p.copyWith(isDefault: false)).toList()..add(withId);
    } else {
      next = [...list, withId];
    }
    await saveAll(next);
    return withId;
  }

  Future<void> update(PrinterDevice device) async {
    final list = await loadAll();
    final updated = list.map((p) => p.id == device.id ? device : p).toList();
    // ensure only one default
    final hasDefault = updated.any((p) => p.isDefault);
    if (hasDefault) {
      final defId = updated.firstWhere((p) => p.isDefault).id;
      for (var i = 0; i < updated.length; i++) {
        updated[i] = updated[i].copyWith(isDefault: updated[i].id == defId);
      }
    }
    await saveAll(updated);
  }

  Future<void> remove(String id) async {
    final list = await loadAll();
    await saveAll(list.where((p) => p.id != id).toList());
  }

  Future<void> setDefault(String id) async {
    final list = await loadAll();
    final updated = list.map((p) => p.copyWith(isDefault: p.id == id)).toList();
    await saveAll(updated);
  }

  Future<void> clear() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.remove(_printersKey);
  }
}

final printerSettingsRepositoryProvider = Provider<PrinterSettingsRepository>((ref) {
  return PrinterSettingsRepository(ref);
});
