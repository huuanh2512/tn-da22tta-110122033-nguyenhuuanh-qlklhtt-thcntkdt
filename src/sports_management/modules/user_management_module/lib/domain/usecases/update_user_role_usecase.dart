import 'package:server_module/server_module.dart';
import '../../data/repositories/admin_user_repository_impl.dart';

class UpdateUserRoleUseCase {
  final AdminUserRepositoryImpl _repository;

  UpdateUserRoleUseCase(this._repository);

  Future<BaseResponse<UserEntity>> call(String id, String role) async {
    return await _repository.updateUserRole(id, role);
  }
}
