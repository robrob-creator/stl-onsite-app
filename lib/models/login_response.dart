import 'user.dart';

class LoginResponse {
  final String message;
  final String token;
  final User user;

  LoginResponse({
    required this.message,
    required this.token,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      message: json['message'] ?? '',
      token: json['data']['token'] ?? '',
      user: User.fromJson(json['data']['user'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'data': {'token': token, 'user': user.toJson()},
    };
  }
}
