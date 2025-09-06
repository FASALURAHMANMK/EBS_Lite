class PosProductDto {
  final int productId;
  final String name;
  final double price;
  final double stock;
  final String? barcode;
  final String? categoryName;

  PosProductDto({
    required this.productId,
    required this.name,
    required this.price,
    required this.stock,
    this.barcode,
    this.categoryName,
  });

  factory PosProductDto.fromJson(Map<String, dynamic> json) => PosProductDto(
        productId: json['product_id'] as int,
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        stock: (json['stock'] as num?)?.toDouble() ?? 0.0,
        barcode: json['barcode'] as String?,
        categoryName: json['category_name'] as String?,
      );
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

class PosCartItem {
  final PosProductDto product;
  final double quantity;
  final double unitPrice;

  PosCartItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  PosCartItem copyWith({double? quantity, double? unitPrice}) => PosCartItem(
        product: product,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );

  double get lineTotal => (quantity * unitPrice);
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

  factory PosCheckoutResult.fromSale(Map<String, dynamic> sale) => PosCheckoutResult(
        saleId: sale['sale_id'] as int,
        saleNumber: sale['sale_number'] as String? ?? '',
        totalAmount: (sale['total_amount'] as num?)?.toDouble() ?? 0.0,
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
  final String? productName;
  final double quantity;
  final double unitPrice;

  SaleItemDto({this.productId, this.productName, required this.quantity, required this.unitPrice});

  factory SaleItemDto.fromJson(Map<String, dynamic> json) => SaleItemDto(
        productId: json['product_id'] as int?,
        productName: json['product_name'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
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

  factory CustomerDetailDto.fromJson(Map<String, dynamic> json) => CustomerDetailDto(
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
  PosPaymentLineDto({required this.methodId, this.currencyId, required this.amount});

  Map<String, dynamic> toJson() => {
        'method_id': methodId,
        if (currencyId != null) 'currency_id': currencyId,
        'amount': amount,
      };
}
