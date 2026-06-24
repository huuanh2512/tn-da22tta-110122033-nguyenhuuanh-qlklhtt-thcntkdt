import 'package:server_module/server_module.dart';

class GetFacilityCourtsUseCase {
  final CourtRepository _courtRepository;

  GetFacilityCourtsUseCase(this._courtRepository);

  Future<BaseResponse<List<CourtEntity>>> call(String facilityId) async {
    final response = await _courtRepository.getCourts();
    if (!response.success || response.data == null) {
      return response;
    }
    final list = response.data!.where((c) => c.facilityId == facilityId).toList();
    return BaseResponse<List<CourtEntity>>(
      success: true,
      message: response.message,
      data: list,
    );
  }
}
