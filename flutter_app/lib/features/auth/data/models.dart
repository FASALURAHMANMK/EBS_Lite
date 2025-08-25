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

class MeResponse {
  final User user;
  final Company? company;

  MeResponse({required this.user, this.company});

  factory MeResponse.fromJson(Map<String, dynamic> json) => MeResponse(
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        company: json['company'] != null
            ? Company.fromJson(json['company'] as Map<String, dynamic>)
            : null,
      );
}
