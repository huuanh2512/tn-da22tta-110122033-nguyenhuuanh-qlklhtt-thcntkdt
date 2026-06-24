import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:authentication_module/authentication_module.dart';
import 'package:facility_module/facility_module.dart';
import 'package:booking_module/booking_module.dart';
import 'staff_court_listing_state.dart';

class StaffCourtListingCubit extends Cubit<StaffCourtListingState> {
  final GetFacilitiesUseCase _getFacilitiesUseCase;
  final GetCourtsUseCase _getCourtsUseCase;
  final GetLocalUserUseCase _getLocalUserUseCase;

  StaffCourtListingCubit(
    this._getFacilitiesUseCase,
    this._getCourtsUseCase,
    this._getLocalUserUseCase,
  ) : super(StaffCourtListingInitial());

  Future<void> loadFacilitiesAndCourts() async {
    emit(StaffCourtListingLoading());
    try {
      final userRes = await _getLocalUserUseCase();
      final user = userRes.fold((_) => null, (u) => u);
      if (user == null || user.userId == null) {
        emit(const StaffCourtListingError('Không thể xác thực người dùng.'));
        return;
      }

      final facilitiesResponse = await _getFacilitiesUseCase();
      if (!facilitiesResponse.success || facilitiesResponse.data == null) {
        emit(
          StaffCourtListingError(
            facilitiesResponse.message ?? 'Lỗi tải danh sách cơ sở.',
          ),
        );
        return;
      }

      final courtsResponse = await _getCourtsUseCase();
      if (!courtsResponse.success || courtsResponse.data == null) {
        emit(
          StaffCourtListingError(
            courtsResponse.message ?? 'Lỗi tải danh sách sân đấu.',
          ),
        );
        return;
      }

      final allFacilities = facilitiesResponse.data!;
      final allCourts = courtsResponse.data!;

      // Lọc cơ sở mà nhân viên quản lý
      var filteredFacilities = allFacilities;
      if (user.role == 'STAFF') {
        filteredFacilities = allFacilities
            .where((f) => f.ownerId == user.userId)
            .toList();
      }

      // Lấy danh sách ID cơ sở đã lọc
      final facilityIds = filteredFacilities.map((f) => f.id).toSet();

      // Lọc các sân đấu thuộc các cơ sở trên
      final filteredCourts = allCourts
          .where((c) => facilityIds.contains(c.facilityId))
          .toList();

      emit(
        StaffCourtListingLoaded(
          facilities: filteredFacilities,
          courts: filteredCourts,
        ),
      );
    } catch (e) {
      emit(StaffCourtListingError('Đã xảy ra lỗi: $e'));
    }
  }
}
