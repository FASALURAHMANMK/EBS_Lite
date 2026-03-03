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
