import 'package:server_module/server_module.dart';
import '../entities/slot_config_entity.dart';

/// Gọi GET /court/:id/slot-config và parse thành SlotConfigEntity
class GetSlotConfigUseCase {
  final CourtRepository _courtRepository;

  GetSlotConfigUseCase(this._courtRepository);

  Future<BaseResponse<SlotConfigEntity>> call(
    String courtId, {
    String? bookingDate,
  }) async {
    final repositoryId = bookingDate != null
        ? '$courtId|bookingDate=$bookingDate&date=$bookingDate'
        : courtId;
    final response = await _courtRepository.getCourtSlotConfig(repositoryId);

    if (!response.success || response.data == null) {
      return BaseResponse<SlotConfigEntity>(
        success: response.success,
        message: response.message,
        data: null,
      );
    }

    try {
      final rawData = response.data as Map<String, dynamic>;
      // API trả về { "config": { ... } }
      final configMap = (rawData['config'] as Map<String, dynamic>?) ?? rawData;

      final slotsList = configMap['slots'] as List<dynamic>? ?? [];
      final slots = slotsList
          .whereType<Map<String, dynamic>>()
          .map(
            (s) => SlotEntity(
              slotIndex: (s['slotIndex'] as num?)?.toInt() ?? 0,
              startMinutes: (s['startMinutes'] as num?)?.toInt() ?? 0,
              endMinutes: (s['endMinutes'] as num?)?.toInt() ?? 0,
              isAvailable: s['isAvailable'] as bool? ?? true,
              status: s['status']?.toString(),
              reason: s['reason']?.toString(),
              blockType: s['blockType']?.toString(),
            ),
          )
          .toList();

      return BaseResponse<SlotConfigEntity>(
        success: true,
        message: response.message,
        data: SlotConfigEntity(
          courtId: configMap['courtId']?.toString() ?? courtId,
          openingMinutes: (configMap['openingMinutes'] as num?)?.toInt() ?? 0,
          closingMinutes:
              (configMap['closingMinutes'] as num?)?.toInt() ?? 1440,
          slotDurationMinutes:
              (configMap['slotDurationMinutes'] as num?)?.toInt() ?? 60,
          slots: slots,
        ),
      );
    } catch (e) {
      return BaseResponse<SlotConfigEntity>(
        success: false,
        message: 'Lỗi parse SlotConfig: $e',
        data: null,
      );
    }
  }
}
