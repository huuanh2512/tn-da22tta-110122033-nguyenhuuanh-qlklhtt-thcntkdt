import 'package:server_module/server_module.dart';

abstract class SportRemoteDataSource {
  Future<BaseResponse<dynamic>> getSports();
  Future<BaseResponse<dynamic>> createSport(Map<String, dynamic> data);
  Future<BaseResponse<dynamic>> updateSport(String id, Map<String, dynamic> data);
  Future<BaseResponse<dynamic>> deleteSport(String id);
}

class SportRemoteDataSourceImpl implements SportRemoteDataSource {
  final SportService _sportService;

  SportRemoteDataSourceImpl(this._sportService);

  @override
  Future<BaseResponse<dynamic>> getSports() {
    return _sportService.getSports();
  }

  @override
  Future<BaseResponse<dynamic>> createSport(Map<String, dynamic> data) {
    return _sportService.createSport(data);
  }

  @override
  Future<BaseResponse<dynamic>> updateSport(String id, Map<String, dynamic> data) {
    return _sportService.updateSport(id, data);
  }

  @override
  Future<BaseResponse<dynamic>> deleteSport(String id) {
    return _sportService.deleteSport(id);
  }
}
