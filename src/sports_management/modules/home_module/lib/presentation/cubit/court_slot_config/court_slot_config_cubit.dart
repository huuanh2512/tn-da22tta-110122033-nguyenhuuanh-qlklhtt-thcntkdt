import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:booking_module/booking_module.dart';
import 'court_slot_config_state.dart';

class CourtSlotConfigCubit extends Cubit<CourtSlotConfigState> {
  final GetSlotConfigUseCase _getSlotConfigUseCase;
  final UpdateCourtSlotConfigUseCase _updateCourtSlotConfigUseCase;

  CourtSlotConfigCubit(
    this._getSlotConfigUseCase,
    this._updateCourtSlotConfigUseCase,
  ) : super(CourtSlotConfigInitial());

  Future<void> loadSlotConfig(String courtId) async {
    emit(CourtSlotConfigLoading());
    try {
      final response = await _getSlotConfigUseCase(courtId);
      if (response.success && response.data != null) {
        emit(CourtSlotConfigLoaded(response.data!));
      } else {
        emit(CourtSlotConfigError(
          response.message ?? 'Không thể tải cấu hình khung giờ.',
        ));
      }
    } catch (e) {
      emit(CourtSlotConfigError('Đã xảy ra lỗi: $e'));
    }
  }

  Future<void> updateSlotConfig({
    required String courtId,
    required int openingMinutes,
    required int closingMinutes,
    required int slotDurationMinutes,
    required List<SlotEntity> slots,
  }) async {
    emit(CourtSlotConfigLoading());
    try {
      final response = await _updateCourtSlotConfigUseCase(
        courtId: courtId,
        openingMinutes: openingMinutes,
        closingMinutes: closingMinutes,
        slotDurationMinutes: slotDurationMinutes,
        slots: slots,
      );

      if (response.success) {
        emit(const CourtSlotConfigSuccess('Cập nhật cấu hình thành công!'));
        // Reload để hiển thị dữ liệu mới nhất
        await loadSlotConfig(courtId);
      } else {
        emit(CourtSlotConfigError(
          response.message ?? 'Cập nhật cấu hình thất bại.',
        ));
      }
    } catch (e) {
      emit(CourtSlotConfigError('Đã xảy ra lỗi khi cập nhật: $e'));
    }
  }
}
