import 'package:shamsi_date/shamsi_date.dart';

/// Convert UTC message instants into dates in the phone's own timezone.
abstract final class PersianNewsDate {
  static const _western = '0123456789';
  static const _persian = '۰۱۲۳۴۵۶۷۸۹';

  static String digits(String text) {
    return text.replaceAllMapped(
      RegExp(r'[0-9]'),
      (match) => _persian[_western.indexOf(match.group(0)!)],
    );
  }

  static String exact(DateTime instant) {
    final local = instant.toLocal();
    final jalali = Jalali.fromDateTime(local);
    final f = jalali.formatter;
    return digits('${f.yyyy}/${f.mm}/${f.dd}');
  }

  static String relative(DateTime instant, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(instant);
    if (elapsed.isNegative || elapsed.inMinutes < 1) return 'همین حالا';
    if (elapsed.inHours < 1) {
      return '${digits('${elapsed.inMinutes}')} دقیقه پیش';
    }
    if (elapsed.inDays < 1) {
      return '${digits('${elapsed.inHours}')} ساعت پیش';
    }
    if (elapsed.inDays < 7) {
      return '${digits('${elapsed.inDays}')} روز پیش';
    }
    return 'بیش از یک هفته پیش';
  }
}
