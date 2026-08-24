import 'package:intl/intl.dart';

class ManilaTime {
  static const Duration _offset = Duration(hours: 8);

  static DateTime now() => DateTime.now().toUtc().add(_offset);

  static DateTime today() {
    final current = now();
    return DateTime(current.year, current.month, current.day);
  }

  static String dateString([DateTime? date]) {
    return DateFormat('yyyy-MM-dd').format(date ?? now());
  }
}
