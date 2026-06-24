import 'package:server_module/server_module.dart';

class DeleteCourtUseCase {
  final CourtRepository _repository;

  DeleteCourtUseCase(this._repository);

  Future<BaseResponse<dynamic>> call(String id) async {
    return await _repository.deleteCourt(id);
  }
}
