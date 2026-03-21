class WarrantyCustomerSnapshotDto {
  final int? customerId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;

  const WarrantyCustomerSnapshotDto({
    this.customerId,
    required this.name,
    this.phone,
    this.email,
    this.address,
  });

  factory WarrantyCustomerSnapshotDto.fromJson(Map<String, dynamic> json) =>
      WarrantyCustomerSnapshotDto(
        customerId: json['customer_id'] as int?,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
      );
}

class WarrantyCandidateDto {
  final int saleDetailId;
  final int productId;
  final int? barcodeId;
  final String productName;
  final String? barcode;
  final String? variantName;
  final String trackingType;
  final bool isSerialized;
  final double quantity;
  final String? serialNumber;
  final int? stockLotId;
  final String? batchNumber;
  final DateTime? batchExpiryDate;
  final int warrantyPeriodMonths;
  final DateTime? warrantyStartDate;
  final DateTime? warrantyEndDate;
  final bool alreadyRegistered;

  const WarrantyCandidateDto({
    required this.saleDetailId,
    required this.productId,
    this.barcodeId,
    required this.productName,
    this.barcode,
    this.variantName,
    this.trackingType = 'VARIANT',
    this.isSerialized = false,
    required this.quantity,
    this.serialNumber,
    this.stockLotId,
    this.batchNumber,
    this.batchExpiryDate,
    required this.warrantyPeriodMonths,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.alreadyRegistered = false,
  });

  factory WarrantyCandidateDto.fromJson(Map<String, dynamic> json) =>
      WarrantyCandidateDto(
        saleDetailId: json['sale_detail_id'] as int? ?? 0,
        productId: json['product_id'] as int? ?? 0,
        barcodeId: json['barcode_id'] as int?,
        productName: json['product_name'] as String? ?? '',
        barcode: json['barcode'] as String?,
        variantName: json['variant_name'] as String?,
        trackingType: json['tracking_type'] as String? ?? 'VARIANT',
        isSerialized: json['is_serialized'] as bool? ?? false,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        serialNumber: json['serial_number'] as String?,
        stockLotId: json['stock_lot_id'] as int?,
        batchNumber: json['batch_number'] as String?,
        batchExpiryDate: _parseDate(json['batch_expiry_date']),
        warrantyPeriodMonths: json['warranty_period_months'] as int? ?? 0,
        warrantyStartDate: _parseDate(json['warranty_start_date']),
        warrantyEndDate: _parseDate(json['warranty_end_date']),
        alreadyRegistered: json['already_registered'] as bool? ?? false,
      );

  String get trackingLabel {
    if (isSerialized) {
      return serialNumber == null || serialNumber!.trim().isEmpty
          ? 'Serialized item'
          : 'Serial ${serialNumber!.trim()}';
    }
    if ((trackingType).toUpperCase() == 'BATCH') {
      return batchNumber == null || batchNumber!.trim().isEmpty
          ? 'Batch tracked'
          : 'Batch ${batchNumber!.trim()}';
    }
    return 'Qty ${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2)}';
  }
}

class WarrantyItemDto {
  final int warrantyItemId;
  final int warrantyId;
  final int saleDetailId;
  final int productId;
  final int? barcodeId;
  final String productName;
  final String? barcode;
  final String? variantName;
  final String trackingType;
  final bool isSerialized;
  final double quantity;
  final String? serialNumber;
  final int? stockLotId;
  final String? batchNumber;
  final DateTime? batchExpiryDate;
  final int warrantyPeriodMonths;
  final DateTime? warrantyStartDate;
  final DateTime? warrantyEndDate;
  final String? notes;

  const WarrantyItemDto({
    required this.warrantyItemId,
    required this.warrantyId,
    required this.saleDetailId,
    required this.productId,
    this.barcodeId,
    required this.productName,
    this.barcode,
    this.variantName,
    this.trackingType = 'VARIANT',
    this.isSerialized = false,
    required this.quantity,
    this.serialNumber,
    this.stockLotId,
    this.batchNumber,
    this.batchExpiryDate,
    required this.warrantyPeriodMonths,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.notes,
  });

  factory WarrantyItemDto.fromJson(Map<String, dynamic> json) =>
      WarrantyItemDto(
        warrantyItemId: json['warranty_item_id'] as int? ?? 0,
        warrantyId: json['warranty_id'] as int? ?? 0,
        saleDetailId: json['sale_detail_id'] as int? ?? 0,
        productId: json['product_id'] as int? ?? 0,
        barcodeId: json['barcode_id'] as int?,
        productName: json['product_name'] as String? ?? '',
        barcode: json['barcode'] as String?,
        variantName: json['variant_name'] as String?,
        trackingType: json['tracking_type'] as String? ?? 'VARIANT',
        isSerialized: json['is_serialized'] as bool? ?? false,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        serialNumber: json['serial_number'] as String?,
        stockLotId: json['stock_lot_id'] as int?,
        batchNumber: json['batch_number'] as String?,
        batchExpiryDate: _parseDate(json['batch_expiry_date']),
        warrantyPeriodMonths: json['warranty_period_months'] as int? ?? 0,
        warrantyStartDate: _parseDate(json['warranty_start_date']),
        warrantyEndDate: _parseDate(json['warranty_end_date']),
        notes: json['notes'] as String?,
      );
}

class WarrantyRegistrationDto {
  final int warrantyId;
  final int companyId;
  final int saleId;
  final String saleNumber;
  final int? customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final String? notes;
  final DateTime? registeredAt;
  final List<WarrantyItemDto> items;

  const WarrantyRegistrationDto({
    required this.warrantyId,
    required this.companyId,
    required this.saleId,
    required this.saleNumber,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.notes,
    this.registeredAt,
    this.items = const [],
  });

  factory WarrantyRegistrationDto.fromJson(Map<String, dynamic> json) =>
      WarrantyRegistrationDto(
        warrantyId: json['warranty_id'] as int? ?? 0,
        companyId: json['company_id'] as int? ?? 0,
        saleId: json['sale_id'] as int? ?? 0,
        saleNumber: json['sale_number'] as String? ?? '',
        customerId: json['customer_id'] as int?,
        customerName: json['customer_name'] as String? ?? '',
        customerPhone: json['customer_phone'] as String?,
        customerEmail: json['customer_email'] as String?,
        customerAddress: json['customer_address'] as String?,
        notes: json['notes'] as String?,
        registeredAt: _parseDate(json['registered_at']),
        items: (json['items'] as List? ?? const [])
            .map((e) => WarrantyItemDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PrepareWarrantyResponseDto {
  final int saleId;
  final String saleNumber;
  final DateTime? saleDate;
  final WarrantyCustomerSnapshotDto? invoiceCustomer;
  final List<WarrantyCandidateDto> eligibleItems;
  final List<WarrantyRegistrationDto> existingWarranties;

  const PrepareWarrantyResponseDto({
    required this.saleId,
    required this.saleNumber,
    this.saleDate,
    this.invoiceCustomer,
    this.eligibleItems = const [],
    this.existingWarranties = const [],
  });

  factory PrepareWarrantyResponseDto.fromJson(Map<String, dynamic> json) =>
      PrepareWarrantyResponseDto(
        saleId: json['sale_id'] as int? ?? 0,
        saleNumber: json['sale_number'] as String? ?? '',
        saleDate: _parseDate(json['sale_date']),
        invoiceCustomer: json['invoice_customer'] is Map<String, dynamic>
            ? WarrantyCustomerSnapshotDto.fromJson(
                json['invoice_customer'] as Map<String, dynamic>,
              )
            : null,
        eligibleItems: (json['eligible_items'] as List? ?? const [])
            .map(
                (e) => WarrantyCandidateDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        existingWarranties: (json['existing_warranties'] as List? ?? const [])
            .map((e) =>
                WarrantyRegistrationDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CreateWarrantyItemPayload {
  final int saleDetailId;
  final double quantity;
  final String? serialNumber;
  final int? stockLotId;

  const CreateWarrantyItemPayload({
    required this.saleDetailId,
    required this.quantity,
    this.serialNumber,
    this.stockLotId,
  });

  Map<String, dynamic> toJson() => {
        'sale_detail_id': saleDetailId,
        'quantity': quantity,
        if (serialNumber != null && serialNumber!.trim().isNotEmpty)
          'serial_number': serialNumber!.trim(),
        if (stockLotId != null) 'stock_lot_id': stockLotId,
      };
}

class CreateWarrantyPayload {
  final String saleNumber;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final String? notes;
  final List<CreateWarrantyItemPayload> items;

  const CreateWarrantyPayload({
    required this.saleNumber,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.notes,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'sale_number': saleNumber,
        if (customerId != null) 'customer_id': customerId,
        if (customerName != null && customerName!.trim().isNotEmpty)
          'customer_name': customerName!.trim(),
        if (customerPhone != null && customerPhone!.trim().isNotEmpty)
          'customer_phone': customerPhone!.trim(),
        if (customerEmail != null && customerEmail!.trim().isNotEmpty)
          'customer_email': customerEmail!.trim(),
        if (customerAddress != null && customerAddress!.trim().isNotEmpty)
          'customer_address': customerAddress!.trim(),
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class WarrantyCompanyDto {
  final int companyId;
  final String name;
  final String? logo;
  final String? address;
  final String? phone;
  final String? email;
  final String? taxNumber;

  const WarrantyCompanyDto({
    required this.companyId,
    required this.name,
    this.logo,
    this.address,
    this.phone,
    this.email,
    this.taxNumber,
  });

  factory WarrantyCompanyDto.fromJson(Map<String, dynamic> json) =>
      WarrantyCompanyDto(
        companyId: json['company_id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        logo: json['logo'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        taxNumber: json['tax_number'] as String?,
      );
}

class WarrantyCardDataDto {
  final WarrantyRegistrationDto warranty;
  final WarrantyCompanyDto company;

  const WarrantyCardDataDto({
    required this.warranty,
    required this.company,
  });

  factory WarrantyCardDataDto.fromJson(Map<String, dynamic> json) =>
      WarrantyCardDataDto(
        warranty: WarrantyRegistrationDto.fromJson(
          json['warranty'] as Map<String, dynamic>? ?? const {},
        ),
        company: WarrantyCompanyDto.fromJson(
          json['company'] as Map<String, dynamic>? ?? const {},
        ),
      );
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
