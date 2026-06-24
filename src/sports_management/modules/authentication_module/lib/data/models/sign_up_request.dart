class SignUpRequest {
  const SignUpRequest({
    required this.email,
    required this.password,
    this.fullName,
    this.phone,
  });

  final String email;
  final String password;
  final String? fullName;
  final String? phone;
}
