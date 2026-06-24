import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/get_facility_courts_usecase.dart';
import '../../../domain/usecases/create_court_usecase.dart';
import '../../../domain/usecases/update_court_usecase.dart';
import '../../../domain/usecases/delete_court_usecase.dart';
import 'court_management_state.dart';

class CourtManagementCubit extends Cubit<CourtManagementState> {
  final GetFacilityCourtsUseCase _getCourtsUseCase;
  final CreateCourtUseCase _createCourtUseCase;
  final UpdateCourtUseCase _updateCourtUseCase;
  final DeleteCourtUseCase _deleteCourtUseCase;

  CourtManagementCubit(
    this._getCourtsUseCase,
    this._createCourtUseCase,
    this._updateCourtUseCase,
    this._deleteCourtUseCase,
  ) : super(CourtManagementInitial());

  Future<void> loadCourts(String facilityId) async {
    emit(CourtManagementLoading());
    try {
      final response = await _getCourtsUseCase(facilityId);
      if (response.success && response.data != null) {
        emit(CourtManagementLoaded(response.data!));
      } else {
        emit(CourtManagementError(response.message ?? 'Lỗi tải danh sách sân'));
      }
    } catch (e) {
      emit(CourtManagementError('Lỗi kết nối: $e'));
    }
  }

  Future<void> createCourt({
    required String facilityId,
    required String sportId,
    required String name,
    required int pricePerHour,
    required String status,
  }) async {
    emit(CourtManagementLoading());
    try {
      final response = await _createCourtUseCase(
        facilityId: facilityId,
        sportId: sportId,
        name: name,
        pricePerHour: pricePerHour,
        status: status,
      );
      if (response.success) {
        emit(const CourtManagementSuccess('Tạo sân mới thành công!'));
        await loadCourts(facilityId);
      } else {
        emit(CourtManagementError(response.message ?? 'Tạo sân thất bại'));
      }
    } catch (e) {
      emit(CourtManagementError('Lỗi: $e'));
    }
  }

  Future<void> updateCourt({
    required String facilityId,
    required String id,
    required String name,
    required int pricePerHour,
    required String status,
  }) async {
    emit(CourtManagementLoading());
    try {
      final response = await _updateCourtUseCase(
        id: id,
        name: name,
        pricePerHour: pricePerHour,
        status: status,
      );
      if (response.success) {
        emit(const CourtManagementSuccess('Cập nhật sân thành công!'));
        await loadCourts(facilityId);
      } else {
        emit(CourtManagementError(response.message ?? 'Cập nhật sân thất bại'));
      }
    } catch (e) {
      emit(CourtManagementError('Lỗi: $e'));
    }
  }

  Future<void> deleteCourt(String facilityId, String id) async {
    emit(CourtManagementLoading());
    try {
      final response = await _deleteCourtUseCase(id);
      if (response.success) {
        emit(const CourtManagementSuccess('Xóa sân thành công!'));
        await loadCourts(facilityId);
      } else {
        emit(CourtManagementError(response.message ?? 'Xóa sân thất bại'));
      }
    } catch (e) {
      emit(CourtManagementError('Lỗi: $e'));
    }
  }
}
