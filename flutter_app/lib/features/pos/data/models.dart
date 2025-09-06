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

