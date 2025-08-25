class User {
  final int userId;
  final String username;
  final String email;

  User({required this.userId, required this.username, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
        userId: json['user_id'] as int,
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}

class Company {
  final int companyId;
  final String name;

  Company({required this.companyId, required this.name});

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        companyId: json['company_id'] as int,
        name: json['name'] as String? ?? '',
      );
}

class UserResponse {
  final int userId;
  final int? companyId;
  final int? locationId;
  final int? roleId;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final bool isActive;
  final bool isLocked;
  final String? preferredLanguage;
  final String? secondaryLanguage;
  final DateTime? lastLogin;
  final List<String>? permissions;
  final Map<String, String>? preferences;

  UserResponse({
    required this.userId,
    this.companyId,
    this.locationId,
    this.roleId,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.isActive = true,
    this.isLocked = false,
    this.preferredLanguage,
    this.secondaryLanguage,
    this.lastLogin,
    this.permissions,
    this.preferences,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) => UserResponse(
        userId: json['user_id'] as int,
        companyId: json['company_id'] as int?,
        locationId: json['location_id'] as int?,
        roleId: json['role_id'] as int?,
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        phone: json['phone'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        isLocked: json['is_locked'] as bool? ?? false,
        preferredLanguage: json['preferred_language'] as String?,
        secondaryLanguage: json['secondary_language'] as String?,
        lastLogin: json['last_login'] != null
            ? DateTime.tryParse(json['last_login'] as String)
            : null,
        permissions: (json['permissions'] as List?)
            ?.map((e) => e.toString())
            .toList(),
        preferences: (json['preferences'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())),
      );

  User toUser() => User(userId: userId, username: username, email: email);
}

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final User user;
  final Company? company;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.user,
    this.company,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        sessionId: json['session_id'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        company: json['company'] != null
            ? Company.fromJson(json['company'] as Map<String, dynamic>)
            : null,
      );
}

class RegisterResponse {
  final int userId;
  final String username;
  final String email;
  final String message;

  RegisterResponse({
    required this.userId,
    required this.username,
    required this.email,
    required this.message,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) =>
      RegisterResponse(
        userId: json['user_id'] as int,
        username: json['username'] as String,
        email: json['email'] as String,
        message: json['message'] as String? ?? '',
      );
}

class CompanyResponse {
  final Company company;
  CompanyResponse(this.company);
  factory CompanyResponse.fromJson(Map<String, dynamic> json) =>
      CompanyResponse(Company.fromJson(json));
}
