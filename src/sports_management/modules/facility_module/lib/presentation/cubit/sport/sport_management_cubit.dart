import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/get_sports_usecase.dart';
import '../../../domain/usecases/create_sport_usecase.dart';
import '../../../domain/usecases/update_sport_usecase.dart';
import '../../../domain/usecases/delete_sport_usecase.dart';
import 'sport_management_state.dart';

class SportManagementCubit extends Cubit<SportManagementState> {
  final GetSportsUseCase _getSportsUseCase;
  final CreateSportUseCase _createSportUseCase;
  final UpdateSportUseCase _updateSportUseCase;
  final DeleteSportUseCase _deleteSportUseCase;

  SportManagementCubit(
    this._getSportsUseCase,
    this._createSportUseCase,
    this._updateSportUseCase,
    this._deleteSportUseCase,
  ) : super(SportManagementInitial());

  Future<void> loadSports() async {
    emit(SportManagementLoading());
    try {
      final response = await _getSportsUseCase();
      if (response.success && response.data != null) {
        emit(SportManagementLoaded(response.data!));
      } else {
        emit(
          SportManagementError(
            response.message ?? 'Lỗi tải danh mục môn thể thao',
          ),
        );
      }
    } catch (e) {
      emit(SportManagementError('Lỗi kết nối: $e'));
    }
  }

  Future<bool> createSport({
    required String name,
    required String description,
    required int teamSize,
    required bool active,
    String? iconUrl,
  }) async {
    emit(SportManagementLoading());
    try {
      final response = await _createSportUseCase(
        name: name,
        description: description,
        teamSize: teamSize,
        active: active,
        iconUrl: iconUrl,
      );
      if (response.success) {
        emit(const SportManagementSuccess('Thêm môn thể thao mới thành công!'));
        await loadSports();
        return true;
      } else {
        emit(
          SportManagementError(
            response.message ?? 'Thêm môn thể thao thất bại',
          ),
        );
        return false;
      }
    } catch (e) {
      emit(SportManagementError('Lỗi: $e'));
      return false;
    }
  }

  Future<bool> updateSport({
    required String id,
    required String name,
    required String description,
    required int teamSize,
    required bool active,
    String? iconUrl,
  }) async {
    emit(SportManagementLoading());
    try {
      final response = await _updateSportUseCase(
        id: id,
        name: name,
        description: description,
        teamSize: teamSize,
        active: active,
        iconUrl: iconUrl,
      );
      if (response.success) {
        emit(const SportManagementSuccess('Cập nhật môn thể thao thành công!'));
        await loadSports();
        return true;
      } else {
        emit(
          SportManagementError(
            response.message ?? 'Cập nhật môn thể thao thất bại',
          ),
        );
        return false;
      }
    } catch (e) {
      emit(SportManagementError('Lỗi: $e'));
      return false;
    }
  }

  Future<void> deleteSport(String id) async {
    emit(SportManagementLoading());
    try {
      final response = await _deleteSportUseCase(id);
      if (response.success) {
        emit(const SportManagementSuccess('Xóa môn thể thao thành công!'));
        await loadSports();
      } else {
        emit(
          SportManagementError(response.message ?? 'Xóa môn thể thao thất bại'),
        );
      }
    } catch (e) {
      emit(SportManagementError('Lỗi: $e'));
    }
  }
}
