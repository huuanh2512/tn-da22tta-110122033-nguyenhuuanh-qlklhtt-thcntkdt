import 'package:server_module/server_module.dart';

class UpdateSportUseCase {
  final SportRepository _repository;

  UpdateSportUseCase(this._repository);

  Future<BaseResponse<SportEntity>> call({
    required String id,
    required String name,
    required String description,
    required int teamSize,
    required bool active,
    String? iconUrl,
  }) async {
    final Map<String, dynamic> data = {
      'name': name,
      'description': description,
      'teamSize': teamSize,
      'active': active,
      'iconUrl': iconUrl,
    };
    return await _repository.updateSport(id, data);
  }
}
