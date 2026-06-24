import 'package:server_module/server_module.dart';

class DeleteSportUseCase {
  final SportRepository _repository;

  DeleteSportUseCase(this._repository);

  Future<BaseResponse<dynamic>> call(String id) async {
    return await _repository.deleteSport(id);
  }
}
