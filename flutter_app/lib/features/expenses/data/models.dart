class ExpenseCategoryDto {
  final int categoryId;
  final String name;

  ExpenseCategoryDto({required this.categoryId, required this.name});

  factory ExpenseCategoryDto.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryDto(
      categoryId: (json['category_id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
    );
  }
}

class ExpenseDto {
  final int expenseId;
  final int categoryId;
  final int locationId;
  final double amount;
  final String? notes;
  final DateTime expenseDate;
  final String? categoryName;
  final String? locationName;

  ExpenseDto({
    required this.expenseId,
    required this.categoryId,
    required this.locationId,
    required this.amount,
    required this.expenseDate,
    this.notes,
    this.categoryName,
    this.locationName,
  });

  factory ExpenseDto.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final location = json['location'];
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v;
      final s = (v ?? '').toString().trim();
      if (s.isEmpty) return DateTime.now();
      return DateTime.tryParse(s) ?? DateTime.now();
    }

    return ExpenseDto(
      expenseId: (json['expense_id'] as num?)?.toInt() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt() ?? 0,
      locationId: (json['location_id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      notes: (json['notes'] as String?)?.trim(),
      expenseDate: parseDate(json['expense_date']),
      categoryName: category is Map<String, dynamic>
          ? (category['name'] as String?)?.trim()
          : (json['category_name'] as String?)?.trim(),
      locationName: location is Map<String, dynamic>
          ? (location['name'] as String?)?.trim()
          : (json['location_name'] as String?)?.trim(),
    );
  }
}
