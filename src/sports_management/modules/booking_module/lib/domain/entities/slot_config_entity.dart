import 'package:equatable/equatable.dart';

class SlotEntity extends Equatable {
  final int slotIndex;
  final int startMinutes;
  final int endMinutes;
  final bool isAvailable;
  final String? status;
  final String? reason;
  final String? blockType;

  const SlotEntity({
    required this.slotIndex,
    required this.startMinutes,
    required this.endMinutes,
    required this.isAvailable,
    this.status,
    this.reason,
    this.blockType,
  });

  /// Ví dụ: 420 → "07:00"
  String get startLabel {
    final h = startMinutes ~/ 60;
    final m = startMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Ví dụ: 480 → "08:00"
  String get endLabel {
    final h = endMinutes ~/ 60;
    final m = endMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
    slotIndex,
    startMinutes,
    endMinutes,
    isAvailable,
    status,
    reason,
    blockType,
  ];
}

class SlotConfigEntity extends Equatable {
  final String courtId;
  final int openingMinutes;
  final int closingMinutes;
  final int slotDurationMinutes;
  final List<SlotEntity> slots;

  const SlotConfigEntity({
    required this.courtId,
    required this.openingMinutes,
    required this.closingMinutes,
    required this.slotDurationMinutes,
    required this.slots,
  });

  @override
  List<Object?> get props => [
    courtId,
    openingMinutes,
    closingMinutes,
    slotDurationMinutes,
    slots,
  ];
}
