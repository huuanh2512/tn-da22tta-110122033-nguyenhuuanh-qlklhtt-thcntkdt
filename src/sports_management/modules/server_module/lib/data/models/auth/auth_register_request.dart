class AuthRegisterRequest {
  final String email;
  final String password;
  final String? fullName;
  final String? phone;

  AuthRegisterRequest({
    required this.email,
    required this.password,
    this.fullName,
    this.phone,
  });
}
