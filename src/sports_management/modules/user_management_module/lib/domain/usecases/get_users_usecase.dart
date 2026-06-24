import 'package:server_module/server_module.dart';
import '../../data/repositories/admin_user_repository_impl.dart';

class GetUsersUseCase {
  final AdminUserRepositoryImpl _repository;

  GetUsersUseCase(this._repository);

  Future<BaseResponse<List<UserEntity>>> call() async {
    return await _repository.getUsers();
  }
}
