class DateDisplayFormatter {
  const DateDisplayFormatter._();

  static String date(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.day)}-${_two(local.month)}-${local.year}';
  }

  static String dateTime(DateTime value) {
    final local = value.toLocal();
    return '${date(local)} ${_two(local.hour)}:${_two(local.minute)}';
  }

  static String fromApiDate(String? value, {String fallback = ''}) {
    if (value == null || value.trim().isEmpty) return fallback;

    final parsed = DateTime.tryParse(value);
    if (parsed != null) return date(parsed);

    final parts = value.split('-');
    if (parts.length == 3 && parts[0].length == 4) {
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    }
    return value;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
