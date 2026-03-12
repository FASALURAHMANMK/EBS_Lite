class CompanySettingsDto {
  final String? name;
  final String? address;
  final String? phone;
  final String? email;

  CompanySettingsDto({
    this.name,
    this.address,
    this.phone,
    this.email,
  });

  factory CompanySettingsDto.fromJson(Map<String, dynamic> json) =>
      CompanySettingsDto(
        name: json['name'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      };
}

class InventorySettingsDto {
  final String inventoryCostingMethod;
  final String negativeStockPolicy;
  final bool hasNegativeStockApprovalPassword;

  const InventorySettingsDto({
    this.inventoryCostingMethod = 'FIFO',
    this.negativeStockPolicy = 'DONT_ALLOW',
    this.hasNegativeStockApprovalPassword = false,
  });

  factory InventorySettingsDto.fromJson(Map<String, dynamic> json) =>
      InventorySettingsDto(
        inventoryCostingMethod:
            json['inventory_costing_method'] as String? ?? 'FIFO',
        negativeStockPolicy:
            json['negative_stock_policy'] as String? ?? 'DONT_ALLOW',
        hasNegativeStockApprovalPassword:
            json['has_negative_stock_approval_password'] as bool? ?? false,
      );
}

class UpdateInventorySettingsDto {
  final String negativeStockPolicy;
  final String? negativeStockApprovalPassword;

  const UpdateInventorySettingsDto({
    required this.negativeStockPolicy,
    this.negativeStockApprovalPassword,
  });

  Map<String, dynamic> toJson() => {
        'negative_stock_policy': negativeStockPolicy,
        if ((negativeStockApprovalPassword ?? '').trim().isNotEmpty)
          'negative_stock_approval_password':
              negativeStockApprovalPassword!.trim(),
      };
}

class InvoiceSettingsDto {
  final String? prefix;
  final int? nextNumber;
  final String? notes;

  InvoiceSettingsDto({this.prefix, this.nextNumber, this.notes});

  factory InvoiceSettingsDto.fromJson(Map<String, dynamic> json) =>
      InvoiceSettingsDto(
        prefix: json['prefix'] as String?,
        nextNumber: (json['next_number'] as num?)?.toInt(),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (prefix != null) 'prefix': prefix,
        if (nextNumber != null) 'next_number': nextNumber,
        if (notes != null) 'notes': notes,
      };
}

class TaxSettingsDto {
  final String? taxName;
  final double? taxPercent;

  TaxSettingsDto({this.taxName, this.taxPercent});

  factory TaxSettingsDto.fromJson(Map<String, dynamic> json) => TaxSettingsDto(
        taxName: json['tax_name'] as String?,
        taxPercent: (json['tax_percent'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (taxName != null) 'tax_name': taxName,
        if (taxPercent != null) 'tax_percent': taxPercent,
      };
}

class DeviceControlSettingsDto {
  final bool allowRemote;

  DeviceControlSettingsDto({required this.allowRemote});

  factory DeviceControlSettingsDto.fromJson(Map<String, dynamic> json) =>
      DeviceControlSettingsDto(
        allowRemote: json['allow_remote'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'allow_remote': allowRemote,
      };
}

class SessionLimitDto {
  final int maxSessions;

  SessionLimitDto({required this.maxSessions});

  factory SessionLimitDto.fromJson(Map<String, dynamic> json) =>
      SessionLimitDto(
        maxSessions: (json['max_sessions'] as num?)?.toInt() ?? 0,
      );
}
