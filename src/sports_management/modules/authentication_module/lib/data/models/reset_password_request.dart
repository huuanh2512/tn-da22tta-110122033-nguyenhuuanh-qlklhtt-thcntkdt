class ResetPasswordRequest {
  const ResetPasswordRequest({
    required this.email,
    required this.otp,
    required this.newPassword,
  });

  final String email;
  final String otp;
  final String newPassword;
}