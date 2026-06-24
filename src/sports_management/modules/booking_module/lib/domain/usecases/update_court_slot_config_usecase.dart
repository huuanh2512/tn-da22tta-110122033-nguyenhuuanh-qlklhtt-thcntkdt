import 'package:server_module/server_module.dart';
import '../entities/slot_config_entity.dart';

class UpdateCourtSlotConfigUseCase {
  final CourtRepository _courtRepository;

  UpdateCourtSlotConfigUseCase(this._courtRepository);

  Future<BaseResponse<dynamic>> call({
    required String courtId,
    required int openingMinutes,
    required int closingMinutes,
    required int slotDurationMinutes,
    required List<SlotEntity> slots,
  }) async {
    final data = {
      'openingMinutes': openingMinutes,
      'closingMinutes': closingMinutes,
      'slotDurationMinutes': slotDurationMinutes,
      'slots': slots.map((s) => {
        'slotIndex': s.slotIndex,
        'startMinutes': s.startMinutes,
        'endMinutes': s.endMinutes,
        'isAvailable': s.isAvailable,
      }).toList(),
    };
    return await _courtRepository.updateCourtSlotConfig(courtId, data);
  }
}
