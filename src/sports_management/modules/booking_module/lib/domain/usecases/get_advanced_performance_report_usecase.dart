import 'package:server_module/server_module.dart';

class GetAdvancedPerformanceReportUseCase {
  final BookingRepository _repository;

  GetAdvancedPerformanceReportUseCase(this._repository);

  Future<BaseResponse<AdvancedPerformanceReportEntity>> call({
    String? facilityId,
    List<String>? facilityIds,
    String? sportId,
    String? courtId,
    String? status,
    String? include,
    required String dateFrom,
    required String dateTo,
  }) {
    return _repository.getAdvancedPerformanceReport(
      facilityId: facilityId,
      facilityIds: facilityIds,
      sportId: sportId,
      courtId: courtId,
      status: status,
      include: include,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }
}
