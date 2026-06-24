import 'package:server_module/server_module.dart';

class GetCourtPerformanceReportUseCase {
  final BookingRepository _repository;

  GetCourtPerformanceReportUseCase(this._repository);

  Future<BaseResponse<CourtPerformanceReportEntity>> call({
    String? facilityId,
    String? courtId,
    required String dateFrom,
    required String dateTo,
  }) {
    return _repository.getCourtPerformanceReport(
      facilityId: facilityId,
      courtId: courtId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }
}
