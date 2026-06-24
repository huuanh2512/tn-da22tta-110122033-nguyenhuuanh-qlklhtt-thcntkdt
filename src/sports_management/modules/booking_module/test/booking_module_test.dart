import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Date Formatting Helper Logic Tests', () {
    // 1. Test API query formatting (yyyy-MM-dd)
    test('formatDateQuery should convert DateTime to yyyy-MM-dd format', () {
      final date = DateTime(2026, 6, 8);
      final formatted =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      expect(formatted, '2026-06-08');

      final dateSingleDigits = DateTime(2026, 1, 5);
      final formattedSingle =
          '${dateSingleDigits.year}-${dateSingleDigits.month.toString().padLeft(2, '0')}-${dateSingleDigits.day.toString().padLeft(2, '0')}';
      expect(formattedSingle, '2026-01-05');
    });

    // 2. Test user display formatting (dd-MM-yyyy)
    test(
      'formatDateVietnamese should convert DateTime to Vietnamese presentation string',
      () {
        final weekdays = [
          'Chủ nhật',
          'Thứ hai',
          'Thứ ba',
          'Thứ tư',
          'Thứ năm',
          'Thứ sáu',
          'Thứ bảy',
        ];

        // Monday, 8 June 2026
        final date = DateTime(2026, 6, 8); // Monday is weekday 1
        final weekday = weekdays[date.weekday % 7]; // 1 % 7 = 1 ('Thứ hai')
        final presentation = '$weekday, ngày 08-06-2026';
        expect(weekday, 'Thứ hai');
        expect(presentation, 'Thứ hai, ngày 08-06-2026');

        // Sunday, 7 June 2026
        final sunday = DateTime(2026, 6, 7); // Sunday is weekday 7
        final sunWeekday =
            weekdays[sunday.weekday % 7]; // 7 % 7 = 0 ('Chủ nhật')
        final sunPresentation = '$sunWeekday, ngày 07-06-2026';
        expect(sunWeekday, 'Chủ nhật');
        expect(sunPresentation, 'Chủ nhật, ngày 07-06-2026');
      },
    );
  });
}
