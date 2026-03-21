import '../../inventory/data/models.dart';

class PosProductDto {
  final int productId;
  final int? comboProductId;
  final int barcodeId;
  final String name;
  final double price;
  final double stock;
  final String? barcode;
  final String? variantName;
  final String? categoryName;
  final String? primaryStorage;
  final bool isVirtualCombo;
  final bool isWeighable;
  final String trackingType;
  final bool isSerialized;
  final String sellingUomMode;
  final int? sellingUnitId;
  final String? sellingUnitName;
  final String? sellingUnitSymbol;

  PosProductDto({
    required this.productId,
    this.comboProductId,
    this.barcodeId = 0,
    required this.name,
    required this.price,
    required this.stock,
    this.barcode,
    this.variantName,
    this.categoryName,
    this.primaryStorage,
    this.isVirtualCombo = false,
    this.isWeighable = false,
    this.trackingType = 'VARIANT',
    this.isSerialized = false,
    this.sellingUomMode = 'LOOSE',
    this.sellingUnitId,
    this.sellingUnitName,
    this.sellingUnitSymbol,
  });

  factory PosProductDto.fromJson(Map<String, dynamic> json) => PosProductDto(
        productId: json['product_id'] as int,
        comboProductId: json['combo_product_id'] as int?,
        barcodeId: json['barcode_id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
        barcode: json['barcode'] as String?,
        variantName: json['variant_name'] as String?,
        categoryName: json['category_name'] as String?,
        primaryStorage: json['primary_storage'] as String?,
        isVirtualCombo: json['is_virtual_combo'] as bool? ?? false,
        isWeighable: json['is_weighable'] as bool? ?? false,
        trackingType: json['tracking_type'] as String? ?? 'VARIANT',
        isSerialized: json['is_serialized'] as bool? ?? false,
        sellingUomMode: json['selling_uom_mode'] as String? ?? 'LOOSE',
        sellingUnitId: json['selling_unit_id'] as int?,
        sellingUnitName: json['selling_unit_name'] as String?,
        sellingUnitSymbol: json['selling_unit_symbol'] as String?,
      );

  String get identityKey => comboProductId != null && comboProductId! > 0
      ? 'combo:$comboProductId'
      : (barcodeId > 0 ? 'barcode:$barcodeId' : 'product:$productId');

  bool get requiresTracking =>
      !isVirtualCombo && (isSerialized || trackingType == 'BATCH');

  String get displayLabel {
    final variant = (variantName ?? '').trim();
    if (variant.isNotEmpty) return '$name • $variant';
    final code = (barcode ?? '').trim();
    if (code.isNotEmpty) return '$name • $code';
    final storage = (primaryStorage ?? '').trim();
    if (storage.isNotEmpty) return '$name • $storage';
    return name;
  }
}

class PosCustomerDto {
  final int customerId;
  final String name;
  final String? phone;
  final String? email;

  PosCustomerDto({
    required this.customerId,
    required this.name,
    this.phone,
    this.email,
  });

  factory PosCustomerDto.fromJson(Map<String, dynamic> json) => PosCustomerDto(
        customerId: json['customer_id'] as int,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
      );
}

class PosComboComponentTracking {
  final int productId;
  final int barcodeId;
  final String productName;
  final String? variantName;
  final double quantityPerCombo;
  final String trackingType;
  final bool isSerialized;
  final InventoryTrackingSelection? tracking;

  const PosComboComponentTracking({
    required this.productId,
    required this.barcodeId,
    required this.productName,
    this.variantName,
    required this.quantityPerCombo,
    this.trackingType = 'VARIANT',
    this.isSerialized = false,
    this.tracking,
  });

  bool get requiresTracking => isSerialized || trackingType == 'BATCH';

  String get displayLabel {
    final variant = (variantName ?? '').trim();
    return variant.isEmpty ? productName : '$productName • $variant';
  }

  PosComboComponentTracking copyWith({
    InventoryTrackingSelection? tracking,
    bool clearTracking = false,
  }) {
    return PosComboComponentTracking(
      productId: productId,
      barcodeId: barcodeId,
      productName: productName,
      variantName: variantName,
      quantityPerCombo: quantityPerCombo,
      trackingType: trackingType,
      isSerialized: isSerialized,
      tracking: clearTracking ? null : (tracking ?? this.tracking),
    );
  }

  bool hasTrackingConfigured(double comboQuantity) {
    if (!requiresTracking) return true;
    final selection = tracking;
    if (selection == null) return false;
    final requiredQuantity = comboQuantity * quantityPerCombo;
    if (isSerialized) {
      return selection.serialNumbers.length == requiredQuantity.round();
    }
    if (trackingType == 'BATCH') {
      final allocated = selection.batchAllocations.fold<double>(
        0,
        (sum, item) => sum + item.quantity,
      );
      return (allocated - requiredQuantity).abs() <= 0.0001;
    }
    return true;
  }

  String summary(double comboQuantity) {
    final requiredQuantity = comboQuantity * quantityPerCombo;
    final selection = tracking;
    final title = [
      productName,
      if ((variantName ?? '').trim().isNotEmpty) variantName!.trim(),
    ].join(' • ');
    if (!requiresTracking) {
      return '$title • ${requiredQuantity.toStringAsFixed(3)}';
    }
    if (selection == null) {
      return '$title • Tracking required';
    }
    return '$title • ${selection.summary(requiredQuantity)}';
  }

  String identityKey(double comboQuantity) {
    if (!requiresTracking) return 'component:$barcodeId';
    final selection = tracking;
    final trackingKey = selection == null
        ? 'unconfigured:${comboQuantity.toStringAsFixed(3)}'
        : [
            if ((selection.barcodeId ?? 0) > 0) 'b:${selection.barcodeId}',
            if (selection.serialNumbers.isNotEmpty)
              's:${selection.serialNumbers.join(",")}',
            if (selection.batchAllocations.isNotEmpty)
              'ba:${selection.batchAllocations.map((e) => '${e.lotId}:${e.quantity}').join(",")}',
          ].join('|');
    return 'component:$barcodeId|$trackingKey';
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'barcode_id': barcodeId,
        'product_name': productName,
        if ((variantName ?? '').trim().isNotEmpty) 'variant_name': variantName,
        'quantity_per_combo': quantityPerCombo,
        'tracking_type': trackingType,
        'is_serialized': isSerialized,
        if (tracking != null) ...tracking!.toIssueJson(),
      };

  factory PosComboComponentTracking.fromJson(Map<String, dynamic> json) => (() {
        final serialNumbers =
            (json['serial_numbers'] as List<dynamic>? ?? const [])
                .map((e) => e.toString())
                .toList();
        final batchAllocations = (json['batch_allocations'] as List<dynamic>? ??
                const [])
            .map((e) =>
                InventoryBatchAllocationDto.fromJson(e as Map<String, dynamic>))
            .toList();
        return PosComboComponentTracking(
          productId: json['product_id'] as int? ?? 0,
          barcodeId: json['barcode_id'] as int? ?? 0,
          productName: json['product_name'] as String? ?? '',
          variantName: json['variant_name'] as String?,
          quantityPerCombo:
              (json['quantity_per_combo'] as num?)?.toDouble() ?? 0.0,
          trackingType: json['tracking_type'] as String? ?? 'VARIANT',
          isSerialized: json['is_serialized'] as bool? ?? false,
          tracking: serialNumbers.isNotEmpty || batchAllocations.isNotEmpty
              ? InventoryTrackingSelection(
                  barcodeId: json['barcode_id'] as int?,
                  trackingType: json['tracking_type'] as String? ?? 'VARIANT',
                  isSerialized: json['is_serialized'] as bool? ?? false,
                  variantName: json['variant_name'] as String?,
                  serialNumbers: serialNumbers,
                  batchAllocations: batchAllocations,
                )
              : null,
        );
      })();
}

class PosCartItem {
  final PosProductDto product;
  final double quantity;
  final double unitPrice;
  final double discountPercent; // 0-100, per-line
  final InventoryTrackingSelection? tracking;
  final List<PosComboComponentTracking> comboTracking;

  PosCartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0.0,
    this.tracking,
    this.comboTracking = const [],
  });

  PosCartItem copyWith(
          {double? quantity,
          double? unitPrice,
          double? discountPercent,
          InventoryTrackingSelection? tracking,
          List<PosComboComponentTracking>? comboTracking,
          bool clearTracking = false}) =>
      PosCartItem(
        product: product,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        discountPercent: discountPercent ?? this.discountPercent,
        tracking: clearTracking ? null : (tracking ?? this.tracking),
        comboTracking: comboTracking ?? this.comboTracking,
      );

  String get identityKey {
    final requiresComboTracking = comboTracking.any((c) => c.requiresTracking);
    if (!product.requiresTracking && !requiresComboTracking) {
      return product.identityKey;
    }
    final trackingKey = tracking == null
        ? 'unconfigured'
        : [
            if ((tracking!.barcodeId ?? 0) > 0) 'b:${tracking!.barcodeId}',
            if (tracking!.serialNumbers.isNotEmpty)
              's:${tracking!.serialNumbers.join(",")}',
            if (tracking!.batchAllocations.isNotEmpty)
              'ba:${tracking!.batchAllocations.map((e) => '${e.lotId}:${e.quantity}').join(",")}',
            if ((tracking!.batchNumber ?? '').trim().isNotEmpty)
              'bn:${tracking!.batchNumber!.trim()}',
          ].join('|');
    final comboKey = comboTracking
        .where((c) => c.requiresTracking)
        .map((c) => c.identityKey(quantity))
        .join('|');
    return '${product.identityKey}|$trackingKey|$comboKey';
  }

  bool get requiresTracking =>
      product.requiresTracking || comboTracking.any((c) => c.requiresTracking);

  bool get requiresDirectTracking => product.requiresTracking;

  bool get requiresComboTracking =>
      comboTracking.any((c) => c.requiresTracking);

  bool get hasTrackingConfigured {
    final directTrackingRequired = product.requiresTracking;
    if (directTrackingRequired) {
      final sel = tracking;
      if (sel == null) return false;
      if (sel.isSerialized) {
        return sel.serialNumbers.length == quantity.round();
      }
      if (sel.trackingType == 'BATCH') {
        final allocated = sel.batchAllocations.fold<double>(
          0,
          (sum, item) => sum + item.quantity,
        );
        if ((allocated - quantity).abs() > 0.0001) return false;
      }
    }
    for (final component in comboTracking) {
      if (!component.hasTrackingConfigured(quantity)) {
        return false;
      }
    }
    return true;
  }

  double get lineTotal {
    final gross = quantity * unitPrice;
    final disc = gross * (discountPercent.clamp(0.0, 100.0) / 100.0);
    return (gross - disc).clamp(0.0, double.infinity);
  }
}

class PosCheckoutResult {
  final int saleId;
  final String saleNumber;
  final double totalAmount;

  PosCheckoutResult({
    required this.saleId,
    required this.saleNumber,
    required this.totalAmount,
  });

  factory PosCheckoutResult.fromSale(Map<String, dynamic> sale) =>
      PosCheckoutResult(
        saleId: sale['sale_id'] as int,
        saleNumber: sale['sale_number'] as String? ?? '',
        totalAmount: (sale['total_amount'] as num?)?.toDouble() ?? 0.0,
      );
}

class PosCouponValidationDto {
  final int couponSeriesId;
  final String seriesName;
  final String code;
  final String discountType;
  final double discountValue;
  final double discountAmount;
  final double minPurchaseAmount;
  final double? maxDiscountAmount;

  const PosCouponValidationDto({
    required this.couponSeriesId,
    required this.seriesName,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.minPurchaseAmount,
    this.maxDiscountAmount,
  });

  factory PosCouponValidationDto.fromJson(Map<String, dynamic> json) =>
      PosCouponValidationDto(
        couponSeriesId: (json['coupon_series_id'] as num?)?.toInt() ?? 0,
        seriesName: json['series_name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        discountType: json['discount_type'] as String? ?? '',
        discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0.0,
        discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
        minPurchaseAmount:
            (json['min_purchase_amount'] as num?)?.toDouble() ?? 0.0,
        maxDiscountAmount: (json['max_discount_amount'] as num?)?.toDouble(),
      );
}

class HeldSaleDto {
  final int saleId;
  final String saleNumber;
  final double totalAmount;
  final String? customerName;

  HeldSaleDto({
    required this.saleId,
    required this.saleNumber,
    required this.totalAmount,
    this.customerName,
  });

  factory HeldSaleDto.fromJson(Map<String, dynamic> json) => HeldSaleDto(
        saleId: json['sale_id'] as int,
        saleNumber: json['sale_number'] as String? ?? '',
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
        customerName: (json['customer'] is Map)
            ? ((json['customer'] as Map)['name'] as String?)
            : null,
      );
}

class CurrencyDto {
  final int currencyId;
  final String code;
  final String? symbol;
  final bool isBase;
  final double exchangeRate; // relative to base

  CurrencyDto({
    required this.currencyId,
    required this.code,
    this.symbol,
    required this.isBase,
    required this.exchangeRate,
  });

  factory CurrencyDto.fromJson(Map<String, dynamic> json) => CurrencyDto(
        currencyId: json['currency_id'] as int,
        code: json['code'] as String? ?? '',
        symbol: json['symbol'] as String?,
        isBase: json['is_base_currency'] as bool? ?? false,
        exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      );
}

class SaleItemDto {
  final int? productId;
  final int? comboProductId;
  final int? barcodeId;
  final String? productName;
  final String? barcode;
  final String? variantName;
  final bool isVirtualCombo;
  final String trackingType;
  final bool isSerialized;
  final double quantity;
  final double unitPrice;
  final double discountPercent;
  final List<String> serialNumbers;
  final List<PosComboComponentTracking> comboComponentTracking;

  SaleItemDto(
      {this.productId,
      this.comboProductId,
      this.barcodeId,
      this.productName,
      this.barcode,
      this.variantName,
      this.isVirtualCombo = false,
      this.trackingType = 'VARIANT',
      this.isSerialized = false,
      required this.quantity,
      required this.unitPrice,
      this.discountPercent = 0.0,
      this.serialNumbers = const [],
      this.comboComponentTracking = const []});

  factory SaleItemDto.fromJson(Map<String, dynamic> json) => SaleItemDto(
        productId: json['product_id'] as int?,
        comboProductId: json['combo_product_id'] as int?,
        barcodeId: json['barcode_id'] as int?,
        productName: json['product_name'] as String?,
        barcode: json['barcode'] as String?,
        variantName: json['variant_name'] as String?,
        isVirtualCombo: json['is_virtual_combo'] as bool? ?? false,
        trackingType: json['tracking_type'] as String? ?? 'VARIANT',
        isSerialized: json['is_serialized'] as bool? ?? false,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
        discountPercent:
            (json['discount_percentage'] as num?)?.toDouble() ?? 0.0,
        serialNumbers: (json['serial_numbers'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        comboComponentTracking: (json['combo_component_tracking']
                    as List<dynamic>? ??
                const [])
            .map((e) =>
                PosComboComponentTracking.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SaleDto {
  final int saleId;
  final String saleNumber;
  final int? customerId;
  final String? customerName;
  final double totalAmount;
  final List<SaleItemDto> items;

  SaleDto({
    required this.saleId,
    required this.saleNumber,
    this.customerId,
    this.customerName,
    required this.totalAmount,
    required this.items,
  });

  factory SaleDto.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .map((e) => SaleItemDto.fromJson(e as Map<String, dynamic>))
        .toList();
    final customer = json['customer'] as Map<String, dynamic>?;
    return SaleDto(
      saleId: json['sale_id'] as int,
      saleNumber: json['sale_number'] as String? ?? '',
      customerId: json['customer_id'] as int?,
      customerName: customer != null ? customer['name'] as String? : null,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      items: items,
    );
  }
}

class CustomerDetailDto {
  final int customerId;
  final String name;
  final double creditLimit;
  final double creditBalance;

  CustomerDetailDto({
    required this.customerId,
    required this.name,
    required this.creditLimit,
    required this.creditBalance,
  });

  factory CustomerDetailDto.fromJson(Map<String, dynamic> json) =>
      CustomerDetailDto(
        customerId: json['customer_id'] as int,
        name: json['name'] as String? ?? '',
        creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
        creditBalance: (json['credit_balance'] as num?)?.toDouble() ?? 0.0,
      );
}

class PosPaymentLineDto {
  final int methodId;
  final int? currencyId;
  final double amount;
  PosPaymentLineDto(
      {required this.methodId, this.currencyId, required this.amount});

  Map<String, dynamic> toJson() => {
        'method_id': methodId,
        if (currencyId != null) 'currency_id': currencyId,
        'amount': amount,
      };
}
