import 'package:server_module/server_module.dart';
import '../../domain/entities/booking_court_model.dart';
import '../datasources/remote/court_remote_data_source.dart';

class CourtRepositoryImpl implements CourtRepository {
  final CourtRemoteDataSource _remoteDataSource;

  CourtRepositoryImpl(this._remoteDataSource);

  @override
  Future<BaseResponse<List<CourtEntity>>> getCourts({
    String? facilityId,
    String? sportId,
  }) async {
    try {
      final response = await _remoteDataSource.getCourts(
        facilityId: facilityId,
        sportId: sportId,
      );
      if (!response.success || response.data == null) {
        return BaseResponse<List<CourtEntity>>(
          success: response.success,
          message: response.message,
          data: null,
        );
      }

      final rawData = response.data as Map<String, dynamic>;
      final itemsList = rawData['items'] as List<dynamic>?;
      final courts = <CourtEntity>[];

      if (itemsList != null) {
        for (final item in itemsList) {
          if (item is Map<String, dynamic>) {
            // API có thể trả về facilityId dạng string hoặc facility dạng object {id, name}
            final facilityId =
                item['facilityId']?.toString() ??
                (item['facility'] is Map
                    ? item['facility']['id']?.toString()
                    : null) ??
                '';
            // API có thể trả về sportId dạng string hoặc sport dạng object {id, name}
            final sportId =
                item['sportId']?.toString() ??
                (item['sport'] is Map
                    ? item['sport']['id']?.toString()
                    : null) ??
                '';
            courts.add(
              BookingCourtModel(
                id: item['_id']?.toString() ?? item['id']?.toString() ?? '',
                facilityId: facilityId,
                sportId: sportId,
                name: item['name']?.toString() ?? '',
                status: item['status']?.toString() ?? 'ACTIVE',
                pricePerHour: (item['pricePerHour'] as num?)?.toInt(),
                code: item['code']?.toString(),
              ),
            );
          }
        }
      }

      return BaseResponse<List<CourtEntity>>(
        success: true,
        message: response.message,
        data: courts,
      );
    } catch (e) {
      return BaseResponse<List<CourtEntity>>(
        success: false,
        message: 'Lỗi parse danh sách CourtEntity: $e',
        data: null,
      );
    }
  }

  @override
  Future<BaseResponse<CourtEntity>> createCourt(
    Map<String, dynamic> data,
  ) async {
    final response = await _remoteDataSource.createCourt(data);
    return _mapToCourtResponse(response);
  }

  @override
  Future<BaseResponse<CourtEntity>> updateCourt(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _remoteDataSource.updateCourt(id, data);
    return _mapToCourtResponse(response);
  }

  @override
  Future<BaseResponse<dynamic>> deleteCourt(String id) {
    return _remoteDataSource.deleteCourt(id);
  }

  @override
  Future<BaseResponse<dynamic>> getCourtSlotConfig(String id) async {
    String actualId = id;
    String query = '';
    if (id.contains('|')) {
      final parts = id.split('|');
      actualId = parts[0];
      query = '?${parts[1]}';
    }

    return _remoteDataSource.getCourtSlotConfig(actualId, query);
  }

  @override
  Future<BaseResponse<dynamic>> updateCourtSlotConfig(
    String id,
    Map<String, dynamic> data,
  ) {
    return _remoteDataSource.updateCourtSlotConfig(id, data);
  }

  BaseResponse<CourtEntity> _mapToCourtResponse(
    BaseResponse<dynamic> response,
  ) {
    if (!response.success || response.data == null) {
      return BaseResponse<CourtEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      final courtMap = (rawData['court'] as Map<String, dynamic>?) ?? rawData;
      // API có thể trả về facilityId dạng string hoặc facility dạng object {id, name}
      final facilityId =
          courtMap['facilityId']?.toString() ??
          (courtMap['facility'] is Map
              ? courtMap['facility']['id']?.toString()
              : null) ??
          '';
      final sportId =
          courtMap['sportId']?.toString() ??
          (courtMap['sport'] is Map
              ? courtMap['sport']['id']?.toString()
              : null) ??
          '';
      final court = BookingCourtModel(
        id: courtMap['_id']?.toString() ?? courtMap['id']?.toString() ?? '',
        facilityId: facilityId,
        sportId: sportId,
        name: courtMap['name']?.toString() ?? '',
        status: courtMap['status']?.toString() ?? 'ACTIVE',
        pricePerHour: (courtMap['pricePerHour'] as num?)?.toInt(),
        code: courtMap['code']?.toString(),
      );
      return BaseResponse<CourtEntity>(
        success: true,
        message: response.message,
        data: court,
      );
    } catch (e) {
      return BaseResponse<CourtEntity>(
        success: false,
        message: 'Lỗi parse CourtEntity: $e',
        data: null,
      );
    }
  }
}
