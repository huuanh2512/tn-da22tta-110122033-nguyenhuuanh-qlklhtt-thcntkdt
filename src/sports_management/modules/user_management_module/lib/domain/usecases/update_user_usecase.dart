import 'package:server_module/server_module.dart';
import '../../data/repositories/admin_user_repository_impl.dart';

class UpdateUserUseCase {
  final AdminUserRepositoryImpl _repository;

  UpdateUserUseCase(this._repository);

  Future<BaseResponse<UserEntity>> call(String id, Map<String, dynamic> data) async {
    return await _repository.updateUser(id, data);
  }
}
