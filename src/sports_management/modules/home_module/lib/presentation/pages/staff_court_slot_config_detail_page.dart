import 'package:booking_module/booking_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../cubit/court_slot_config/court_slot_config_cubit.dart';
import '../cubit/court_slot_config/court_slot_config_state.dart';

class StaffCourtSlotConfigDetailPage extends StatefulWidget {
  final String courtId;
  final String courtName;
  final String? sportName;
  final String? courtStatus;

  const StaffCourtSlotConfigDetailPage({
    super.key,
    required this.courtId,
    required this.courtName,
    this.sportName,
    this.courtStatus,
  });

  @override
  State<StaffCourtSlotConfigDetailPage> createState() =>
      _StaffCourtSlotConfigDetailPageState();
}

class _StaffCourtSlotConfigDetailPageState
    extends State<StaffCourtSlotConfigDetailPage> {
  static const _primaryColor = Color(0xFFFF5600);

  late final CourtSlotConfigCubit _cubit;
  int? _openingMinutes;
  int? _closingMinutes;
  int? _slotDurationMinutes;
  List<SlotEntity> _slots = const [];
  bool _initialized = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _cubit = CourtSlotConfigCubit(GetIt.I(), GetIt.I());
    _cubit.loadSlotConfig(widget.courtId);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${remainder.toString().padLeft(2, '0')}';
  }

  void _applyConfig(SlotConfigEntity config) {
    setState(() {
      _openingMinutes = config.openingMinutes;
      _closingMinutes = config.closingMinutes;
      _slotDurationMinutes = config.slotDurationMinutes;
      _slots = List<SlotEntity>.from(config.slots);
      _initialized = true;
      _hasChanges = false;
    });
  }

  void _regenerateSlots() {
    final opening = _openingMinutes;
    final closing = _closingMinutes;
    final duration = _slotDurationMinutes;
    if (opening == null || closing == null || duration == null) return;

    final newSlots = <SlotEntity>[];
    var slotIndex = 1;
    for (
      var minute = opening;
      minute + duration <= closing;
      minute += duration
    ) {
      final previous = _slots.where(
        (slot) =>
            slot.startMinutes == minute && slot.endMinutes == minute + duration,
      );
      newSlots.add(
        SlotEntity(
          slotIndex: slotIndex,
          startMinutes: minute,
          endMinutes: minute + duration,
          isAvailable: previous.isEmpty ? true : previous.first.isAvailable,
        ),
      );
      slotIndex++;
    }

    setState(() {
      _slots = newSlots;
      _hasChanges = true;
    });
  }

  Future<void> _selectTime({required bool opening}) async {
    final current = opening ? _openingMinutes : _closingMinutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (current ?? (opening ? 420 : 1320)) ~/ 60,
        minute: (current ?? (opening ? 420 : 1320)) % 60,
      ),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: _primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (selected == null) return;

    final minutes = selected.hour * 60 + selected.minute;
    setState(() {
      if (opening) {
        _openingMinutes = minutes;
      } else {
        _closingMinutes = minutes;
      }
    });
    _regenerateSlots();
  }

  void _toggleSlotStatus(int index) {
    final slot = _slots[index];
    setState(() {
      _slots = List<SlotEntity>.from(_slots)
        ..[index] = SlotEntity(
          slotIndex: slot.slotIndex,
          startMinutes: slot.startMinutes,
          endMinutes: slot.endMinutes,
          isAvailable: !slot.isAvailable,
        );
      _hasChanges = true;
    });
  }

  void _saveConfig() {
    final opening = _openingMinutes;
    final closing = _closingMinutes;
    final duration = _slotDurationMinutes;
    if (opening == null || closing == null || duration == null) return;

    if (opening >= closing) {
      _showMessage('Giờ mở cửa phải trước giờ đóng cửa.');
      return;
    }
    if (closing - opening < duration || _slots.isEmpty) {
      _showMessage(
        'Khoảng thời gian hoạt động phải đủ cho ít nhất một khung giờ.',
      );
      return;
    }

    _cubit.updateSlotConfig(
      courtId: widget.courtId,
      openingMinutes: opening,
      closingMinutes: closing,
      slotDurationMinutes: duration,
      slots: _slots,
    );
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Widget _buildCourtSummary(ThemeData theme) {
    final isActive =
        widget.courtStatus == null || widget.courtStatus == 'ACTIVE';
    final isMaintenance = widget.courtStatus == 'MAINTENANCE';
    final statusColor = isActive
        ? Colors.green
        : isMaintenance
        ? Colors.orange
        : Colors.grey;
    final statusLabel = isActive
        ? 'Hoạt động'
        : isMaintenance
        ? 'Bảo trì'
        : 'Tạm ngưng';
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.sports_tennis_rounded,
                color: _primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.courtName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.sportName ?? 'Môn thể thao',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSettings(ThemeData theme) {
    Widget timeField({
      required String label,
      required int? value,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.schedule_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              value == null ? '--:--' : _formatMinutes(value),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thời gian hoạt động',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            timeField(
              label: 'Giờ mở cửa',
              value: _openingMinutes,
              onTap: () => _selectTime(opening: true),
            ),
            const SizedBox(width: 12),
            timeField(
              label: 'Giờ đóng cửa',
              value: _closingMinutes,
              onTap: () => _selectTime(opening: false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _slotDurationMinutes,
          decoration: InputDecoration(
            labelText: 'Thời lượng mỗi khung giờ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 30, child: Text('30 phút')),
            DropdownMenuItem(value: 45, child: Text('45 phút')),
            DropdownMenuItem(value: 60, child: Text('60 phút')),
            DropdownMenuItem(value: 90, child: Text('90 phút')),
            DropdownMenuItem(value: 120, child: Text('120 phút')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _slotDurationMinutes = value);
            _regenerateSlots();
          },
        ),
      ],
    );
  }

  Widget _buildSlotGrid(ThemeData theme) {
    if (_slots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Chưa có khung giờ. Hãy kiểm tra giờ hoạt động và thời lượng.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
            ? 3
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _slots.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.75,
          ),
          itemBuilder: (context, index) {
            final slot = _slots[index];
            final available = slot.isAvailable;
            final color = available ? Colors.green : Colors.grey;
            return InkWell(
              onTap: () => _toggleSlotStatus(index),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.38)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          available
                              ? Icons.check_circle_outline_rounded
                              : Icons.pause_circle_outline_rounded,
                          color: color,
                          size: 18,
                        ),
                        const Spacer(),
                        Text(
                          '#${slot.slotIndex}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_formatMinutes(slot.startMinutes)} - '
                      '${_formatMinutes(slot.endMinutes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        available ? 'Hoạt động' : 'Tạm ngưng',
                        style: TextStyle(
                          color: available
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cấu hình khung giờ')),
      bottomNavigationBar:
          BlocBuilder<CourtSlotConfigCubit, CourtSlotConfigState>(
            bloc: _cubit,
            builder: (context, state) {
              if (!_initialized) return const SizedBox.shrink();
              final saving = state is CourtSlotConfigLoading;
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _hasChanges && !saving ? _saveConfig : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Lưu cấu hình',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              );
            },
          ),
      body: BlocConsumer<CourtSlotConfigCubit, CourtSlotConfigState>(
        bloc: _cubit,
        listener: (context, state) {
          if (state is CourtSlotConfigLoaded) {
            _applyConfig(state.config);
          } else if (state is CourtSlotConfigSuccess) {
            setState(() => _hasChanges = false);
            _showMessage('Đã lưu cấu hình khung giờ');
          } else if (state is CourtSlotConfigError && _initialized) {
            _showMessage(state.message, error: true);
          }
        },
        builder: (context, state) {
          if (!_initialized && state is CourtSlotConfigLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }
          if (!_initialized && state is CourtSlotConfigError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _cubit.loadSlotConfig(widget.courtId),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn trạng thái cho từng khung giờ của sân',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCourtSummary(theme),
                const SizedBox(height: 24),
                _buildTimeSettings(theme),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Danh sách khung giờ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${_slots.length} khung giờ',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSlotGrid(theme),
              ],
            ),
          );
        },
      ),
    );
  }
}
