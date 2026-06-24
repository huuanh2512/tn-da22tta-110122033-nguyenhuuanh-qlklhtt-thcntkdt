import 'package:server_module/server_module.dart';
import '../../data/repositories/admin_user_repository_impl.dart';

class UpdateUserStatusUseCase {
  final AdminUserRepositoryImpl _repository;

  UpdateUserStatusUseCase(this._repository);

  Future<BaseResponse<UserEntity>> call(String id, String status) async {
    return await _repository.updateUserStatus(id, status);
  }
}
