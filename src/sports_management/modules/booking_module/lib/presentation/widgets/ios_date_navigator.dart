import 'package:flutter/material.dart';
import 'package:server_module/server_module.dart';

class IosDateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime minDate;
  final DateTime maxDate;
  final ValueChanged<DateTime> onDateChanged;
  final bool enabled;

  const IosDateNavigator({
    super.key,
    required this.selectedDate,
    required this.minDate,
    required this.maxDate,
    required this.onDateChanged,
    this.enabled = true,
  });

  String _formatDateVietnamese(DateTime date) {
    final weekdays = [
      'Chủ nhật',
      'Thứ hai',
      'Thứ ba',
      'Thứ tư',
      'Thứ năm',
      'Thứ sáu',
      'Thứ bảy',
    ];
    final weekday = weekdays[date.weekday % 7];
    return '$weekday, ngày ${DateDisplayFormatter.date(date)}';
  }

  bool get _isAtMin =>
      selectedDate.year == minDate.year &&
      selectedDate.month == minDate.month &&
      selectedDate.day == minDate.day;

  bool get _isAtMax =>
      selectedDate.year == maxDate.year &&
      selectedDate.month == maxDate.month &&
      selectedDate.day == maxDate.day;

  void _onPreviousDay() {
    if (_isAtMin || !enabled) return;
    onDateChanged(selectedDate.subtract(const Duration(days: 1)));
  }

  void _onNextDay() {
    if (_isAtMax || !enabled) return;
    onDateChanged(selectedDate.add(const Duration(days: 1)));
  }

  Future<void> _selectDateFromPicker(BuildContext context) async {
    if (!enabled) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: minDate,
      lastDate: maxDate,
      builder: (BuildContext context, Widget? child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: const Color(0xFFFF5600), // Accent color
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPrev = enabled && !_isAtMin;
    final canNext = enabled && !_isAtMax;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Back Button
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: canPrev ? const Color(0xFFFF5600) : Colors.grey.shade300,
              size: 20,
            ),
            onPressed: canPrev ? _onPreviousDay : null,
          ),

          // Center Date Display Area
          Expanded(
            child: InkWell(
              onTap: () => _selectDateFromPicker(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 12.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: enabled ? const Color(0xFFFF5600) : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _formatDateVietnamese(selectedDate),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: enabled
                              ? theme.textTheme.bodyLarge?.color
                              : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right Forward Button
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios_rounded,
              color: canNext ? const Color(0xFFFF5600) : Colors.grey.shade300,
              size: 20,
            ),
            onPressed: canNext ? _onNextDay : null,
          ),
        ],
      ),
    );
  }
}
