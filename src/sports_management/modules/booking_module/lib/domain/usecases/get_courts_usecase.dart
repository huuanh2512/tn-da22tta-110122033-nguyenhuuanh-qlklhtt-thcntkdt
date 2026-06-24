import 'package:server_module/server_module.dart';

class GetCourtsUseCase {
  final CourtRepository _courtRepository;

  GetCourtsUseCase(this._courtRepository);

  Future<BaseResponse<List<CourtEntity>>> call({
    String? facilityId,
    String? sportId,
  }) async {
    final response = await _courtRepository.getCourts(
      facilityId: facilityId,
      sportId: sportId,
    );
    if (!response.success || response.data == null) {
      return response;
    }

    var list = response.data!;
    if (facilityId != null && facilityId.isNotEmpty) {
      list = list.where((c) => c.facilityId == facilityId).toList();
    }
    if (sportId != null && sportId.isNotEmpty) {
      list = list.where((c) => c.sportId == sportId).toList();
    }

    return BaseResponse<List<CourtEntity>>(
      success: true,
      message: response.message,
      data: list,
    );
  }
}
