class UpdateProfileRequest {
  const UpdateProfileRequest({
    required this.userId,
    this.name,
    this.phone,
    this.facilityName,
    this.avatar,
  });

  final String userId;
  final String? name;
  final String? phone;
  final String? facilityName;
  final String? avatar;
}