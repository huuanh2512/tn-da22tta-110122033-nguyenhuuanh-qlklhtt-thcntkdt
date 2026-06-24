import 'package:server_module/server_module.dart';
import '../../domain/entities/sport_catalog_entity.dart';
import '../datasources/remote/sport_remote_data_source.dart';

class SportRepositoryImpl implements SportRepository {
  final SportRemoteDataSource _remoteDataSource;

  SportRepositoryImpl(this._remoteDataSource);

  @override
  Future<BaseResponse<List<SportEntity>>> getSports() async {
    final response = await _remoteDataSource.getSports();
    if (!response.success || response.data == null) {
      return BaseResponse<List<SportEntity>>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final itemsList = rawData['items'] as List<dynamic>?;
      final sports = <SportEntity>[];

      if (itemsList != null) {
        for (final item in itemsList) {
          if (item is Map<String, dynamic>) {
            final activeVal = item['active'];
            final statusVal = item['status'];
            final teamSizeVal = item['teamSize'];
            sports.add(
              SportCatalogEntity(
                id: item['_id']?.toString() ?? item['id']?.toString() ?? '',
                name: item['name']?.toString() ?? '',
                iconUrl: item['iconUrl']?.toString() ?? '',
                description: item['description']?.toString() ?? '',
                teamSize: teamSizeVal is num ? teamSizeVal.toInt() : int.tryParse(teamSizeVal?.toString() ?? ''),
                active: activeVal == true || statusVal == 'ACTIVE' || activeVal == null,
              ),
            );
          }
        }
      }

      return BaseResponse<List<SportEntity>>(
        success: true,
        message: response.message,
        data: sports,
      );
    } catch (e) {
      return BaseResponse<List<SportEntity>>(
        success: false,
        message: 'Lỗi parse danh sách SportEntity: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<SportEntity>> createSport(Map<String, dynamic> data) async {
    final response = await _remoteDataSource.createSport(data);
    return _mapToSportResponse(response);
  }

  @override
  Future<BaseResponse<SportEntity>> updateSport(String id, Map<String, dynamic> data) async {
    final response = await _remoteDataSource.updateSport(id, data);
    return _mapToSportResponse(response);
  }

  @override
  Future<BaseResponse<dynamic>> deleteSport(String id) {
    return _remoteDataSource.deleteSport(id);
  }

  BaseResponse<SportEntity> _mapToSportResponse(BaseResponse<dynamic> response) {
    if (!response.success || response.data == null) {
      return BaseResponse<SportEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final sportMap = (rawData['sport'] as Map<String, dynamic>?) ?? rawData;
      final activeVal = sportMap['active'];
      final statusVal = sportMap['status'];
      final teamSizeVal = sportMap['teamSize'];
      final sport = SportCatalogEntity(
        id: sportMap['_id']?.toString() ?? sportMap['id']?.toString() ?? '',
        name: sportMap['name']?.toString() ?? '',
        iconUrl: sportMap['iconUrl']?.toString() ?? '',
        description: sportMap['description']?.toString() ?? '',
        teamSize: teamSizeVal is num ? teamSizeVal.toInt() : int.tryParse(teamSizeVal?.toString() ?? ''),
        active: activeVal == true || statusVal == 'ACTIVE' || activeVal == null,
      );
      return BaseResponse<SportEntity>(
        success: true,
        message: response.message,
        data: sport,
      );
    } catch (e) {
      return BaseResponse<SportEntity>(
        success: false,
        message: 'Lỗi parse SportEntity: $e',
        data: null,
      );
    }
  }
}
