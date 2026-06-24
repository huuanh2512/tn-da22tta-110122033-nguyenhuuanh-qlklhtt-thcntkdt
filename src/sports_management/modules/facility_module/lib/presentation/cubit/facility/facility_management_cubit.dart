import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/get_facilities_usecase.dart';
import '../../../domain/usecases/create_facility_usecase.dart';
import '../../../domain/usecases/update_facility_usecase.dart';
import '../../../domain/usecases/delete_facility_usecase.dart';
import 'facility_management_state.dart';

class FacilityManagementCubit extends Cubit<FacilityManagementState> {
  final GetFacilitiesUseCase _getFacilitiesUseCase;
  final CreateFacilityUseCase _createFacilityUseCase;
  final UpdateFacilityUseCase _updateFacilityUseCase;
  final DeleteFacilityUseCase _deleteFacilityUseCase;

  FacilityManagementCubit(
    this._getFacilitiesUseCase,
    this._createFacilityUseCase,
    this._updateFacilityUseCase,
    this._deleteFacilityUseCase,
  ) : super(FacilityManagementInitial());

  Future<void> loadFacilities() async {
    emit(FacilityManagementLoading());
    try {
      final response = await _getFacilitiesUseCase();
      if (response.success && response.data != null) {
        emit(FacilityManagementLoaded(response.data!));
      } else {
        emit(FacilityManagementError(response.message ?? 'Lỗi tải danh sách cơ sở'));
      }
    } catch (e) {
      emit(FacilityManagementError('Lỗi kết nối: $e'));
    }
  }

  Future<void> createFacility({
    required String name,
    required String address,
    required String city,
    required List<String> staffIds,
    required bool active,
  }) async {
    emit(FacilityManagementLoading());
    try {
      final response = await _createFacilityUseCase(
        name: name,
        address: address,
        city: city,
        staffIds: staffIds,
        active: active,
      );
      if (response.success) {
        emit(const FacilityManagementSuccess('Tạo cơ sở mới thành công!'));
        await loadFacilities();
      } else {
        emit(FacilityManagementError(response.message ?? 'Tạo cơ sở thất bại'));
      }
    } catch (e) {
      emit(FacilityManagementError('Lỗi: $e'));
    }
  }

  Future<void> updateFacility({
    required String id,
    required String name,
    required String address,
    required String city,
    required List<String> staffIds,
    required bool active,
  }) async {
    emit(FacilityManagementLoading());
    try {
      final response = await _updateFacilityUseCase(
        id: id,
        name: name,
        address: address,
        city: city,
        staffIds: staffIds,
        active: active,
      );
      if (response.success) {
        emit(const FacilityManagementSuccess('Cập nhật cơ sở thành công!'));
        await loadFacilities();
      } else {
        emit(FacilityManagementError(response.message ?? 'Cập nhật cơ sở thất bại'));
      }
    } catch (e) {
      emit(FacilityManagementError('Lỗi: $e'));
    }
  }

  Future<void> deleteFacility(String id) async {
    emit(FacilityManagementLoading());
    try {
      final response = await _deleteFacilityUseCase(id);
      if (response.success) {
        emit(const FacilityManagementSuccess('Xóa cơ sở thành công!'));
        await loadFacilities();
      } else {
        emit(FacilityManagementError(response.message ?? 'Xóa cơ sở thất bại'));
      }
    } catch (e) {
      emit(FacilityManagementError('Lỗi: $e'));
    }
  }
}
