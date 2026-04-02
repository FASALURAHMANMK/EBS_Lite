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
  final String negativeProfitPolicy;
  final bool hasNegativeStockApprovalPassword;

  const InventorySettingsDto({
    this.inventoryCostingMethod = 'FIFO',
    this.negativeStockPolicy = 'DONT_ALLOW',
    this.negativeProfitPolicy = 'DONT_ALLOW',
    this.hasNegativeStockApprovalPassword = false,
  });

  factory InventorySettingsDto.fromJson(Map<String, dynamic> json) =>
      InventorySettingsDto(
        inventoryCostingMethod:
            json['inventory_costing_method'] as String? ?? 'FIFO',
        negativeStockPolicy:
            json['negative_stock_policy'] as String? ?? 'DONT_ALLOW',
        negativeProfitPolicy:
            json['negative_profit_policy'] as String? ?? 'DONT_ALLOW',
        hasNegativeStockApprovalPassword:
            json['has_negative_stock_approval_password'] as bool? ?? false,
      );
}

class UpdateInventorySettingsDto {
  final String negativeStockPolicy;
  final String negativeProfitPolicy;
  final String? negativeStockApprovalPassword;

  const UpdateInventorySettingsDto({
    required this.negativeStockPolicy,
    required this.negativeProfitPolicy,
    this.negativeStockApprovalPassword,
  });

  Map<String, dynamic> toJson() => {
        'negative_stock_policy': negativeStockPolicy,
        'negative_profit_policy': negativeProfitPolicy,
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

class SecurityPolicyDto {
  final int minPasswordLength;
  final bool requireUppercase;
  final bool requireLowercase;
  final bool requireNumber;
  final bool requireSpecial;
  final int sessionIdleTimeoutMins;
  final int elevatedAccessWindowMins;

  const SecurityPolicyDto({
    this.minPasswordLength = 10,
    this.requireUppercase = true,
    this.requireLowercase = true,
    this.requireNumber = true,
    this.requireSpecial = true,
    this.sessionIdleTimeoutMins = 480,
    this.elevatedAccessWindowMins = 5,
  });

  factory SecurityPolicyDto.fromJson(Map<String, dynamic> json) =>
      SecurityPolicyDto(
        minPasswordLength: (json['min_password_length'] as num?)?.toInt() ?? 10,
        requireUppercase: json['require_uppercase'] as bool? ?? true,
        requireLowercase: json['require_lowercase'] as bool? ?? true,
        requireNumber: json['require_number'] as bool? ?? true,
        requireSpecial: json['require_special'] as bool? ?? true,
        sessionIdleTimeoutMins:
            (json['session_idle_timeout_mins'] as num?)?.toInt() ?? 480,
        elevatedAccessWindowMins:
            (json['elevated_access_window_mins'] as num?)?.toInt() ?? 5,
      );

  Map<String, dynamic> toJson() => {
        'min_password_length': minPasswordLength,
        'require_uppercase': requireUppercase,
        'require_lowercase': requireLowercase,
        'require_number': requireNumber,
        'require_special': requireSpecial,
        'session_idle_timeout_mins': sessionIdleTimeoutMins,
        'elevated_access_window_mins': elevatedAccessWindowMins,
      };
}

class SupportIssueSubmissionDto {
  final String title;
  final String severity;
  final String details;
  final String appVersion;
  final String buildNumber;
  final String releaseChannel;
  final String platform;
  final String platformVersion;
  final bool backendReachable;
  final int queuedSyncItems;
  final String? lastSyncAt;

  const SupportIssueSubmissionDto({
    required this.title,
    required this.severity,
    required this.details,
    required this.appVersion,
    required this.buildNumber,
    required this.releaseChannel,
    required this.platform,
    required this.platformVersion,
    required this.backendReachable,
    required this.queuedSyncItems,
    this.lastSyncAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'severity': severity,
        'details': details,
        'app_version': appVersion,
        'build_number': buildNumber,
        'release_channel': releaseChannel,
        'platform': platform,
        'platform_version': platformVersion,
        'backend_reachable': backendReachable,
        'queued_sync_items': queuedSyncItems,
        if ((lastSyncAt ?? '').trim().isNotEmpty) 'last_sync_at': lastSyncAt,
      };
}

class SubmittedSupportIssueDto {
  final int issueId;
  final String issueNumber;
  final String status;
  final DateTime? createdAt;

  const SubmittedSupportIssueDto({
    required this.issueId,
    required this.issueNumber,
    required this.status,
    required this.createdAt,
  });

  factory SubmittedSupportIssueDto.fromJson(Map<String, dynamic> json) =>
      SubmittedSupportIssueDto(
        issueId: (json['issue_id'] as num?)?.toInt() ?? 0,
        issueNumber: json['issue_number'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );
}
