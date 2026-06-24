import 'package:server_module/server_module.dart';

class UserCatalogEntity extends UserEntity {
  final String? facilityName;
  final String? facilityId;

  const UserCatalogEntity({
    required super.id,
    super.email,
    super.name,
    super.avatar,
    super.phone,
    super.role,
    super.status,
    super.createdAt,
    this.facilityName,
    this.facilityId,
  });

  @override
  List<Object?> get props => [...super.props, facilityName, facilityId];
}
