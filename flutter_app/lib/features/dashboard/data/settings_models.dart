class CompanySettingsDto {
  final String? name;
  final String? address;
  final String? phone;
  final String? email;

  CompanySettingsDto({this.name, this.address, this.phone, this.email});

  factory CompanySettingsDto.fromJson(Map<String, dynamic> json) => CompanySettingsDto(
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

