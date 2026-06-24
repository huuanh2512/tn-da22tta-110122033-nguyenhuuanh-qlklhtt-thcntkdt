import 'package:server_module/server_module.dart';

class GetSportsUseCase {
  final SportRepository _sportRepository;

  GetSportsUseCase(this._sportRepository);

  Future<BaseResponse<List<SportEntity>>> call() {
    return _sportRepository.getSports();
  }
}
