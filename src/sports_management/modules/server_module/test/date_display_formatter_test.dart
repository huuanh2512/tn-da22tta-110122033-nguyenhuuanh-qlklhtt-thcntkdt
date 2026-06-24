import 'package:flutter_test/flutter_test.dart';
import 'package:server_module/server_module.dart';

void main() {
  group('DateDisplayFormatter', () {
    test('formats DateTime as dd-MM-yyyy', () {
      expect(DateDisplayFormatter.date(DateTime(2026, 6, 8)), '08-06-2026');
    });

    test('formats API date as dd-MM-yyyy', () {
      expect(DateDisplayFormatter.fromApiDate('2026-06-15'), '15-06-2026');
    });

    test('keeps fallback for an empty API date', () {
      expect(DateDisplayFormatter.fromApiDate(null, fallback: '--'), '--');
    });
  });
}
