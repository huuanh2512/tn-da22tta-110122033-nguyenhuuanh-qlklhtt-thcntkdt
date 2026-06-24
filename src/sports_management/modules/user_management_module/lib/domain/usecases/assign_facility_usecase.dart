import 'package:server_module/server_module.dart';
import '../../data/repositories/admin_user_repository_impl.dart';

class AssignFacilityUseCase {
  final AdminUserRepositoryImpl _repository;

  AssignFacilityUseCase(this._repository);

  Future<BaseResponse<UserEntity>> call(String id, String facilityId) async {
    return await _repository.assignFacility(id, facilityId);
  }
}
