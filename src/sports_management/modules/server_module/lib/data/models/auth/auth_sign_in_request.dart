import 'package:equatable/equatable.dart';

class AuthSignInRequest extends Equatable {
  final String email;
  final String password;

  const AuthSignInRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }

  @override
  List<Object?> get props => [email, password];
}