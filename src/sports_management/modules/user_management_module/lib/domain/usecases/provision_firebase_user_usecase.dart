import 'package:server_module/server_module.dart';

import '../../data/repositories/admin_user_repository_impl.dart';

class ProvisionFirebaseUserUseCase {
  const ProvisionFirebaseUserUseCase(this._repository);

  final AdminUserRepositoryImpl _repository;

  Future<BaseResponse<dynamic>> call({
    required String email,
    required String role,
    required String name,
    required String phone,
    String? facilityId,
  }) => _repository.provisionFirebaseUser(
    email: email,
    role: role,
    name: name,
    phone: phone,
    facilityId: facilityId,
  );
}
