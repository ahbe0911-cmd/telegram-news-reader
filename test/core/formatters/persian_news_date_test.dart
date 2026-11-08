import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_news_reader/core/formatters/persian_news_date.dart';

void main() {
  test('exact Jalali date uses the local day and Persian digits', () {
    // Midday avoids timezone rollover in the reference example.
    expect(
      PersianNewsDate.exact(DateTime(2026, 11, 8, 12)),
      '۱۴۰۵/۰۸/۱۷',
    );
    expect(
      PersianNewsDate.exact(DateTime(2026, 3, 21, 12)),
      '۱۴۰۵/۰۱/۰۱',
    );
  });

  test('relative dates remain Persian and show the exact elapsed time', () {
    final now = DateTime(2026, 11, 8, 12);
    expect(
      PersianNewsDate.relative(
        now.subtract(const Duration(hours: 2)), now: now,
      ),
      '۲ ساعت پیش',
    );
    expect(
      PersianNewsDate.relative(
        now.subtract(const Duration(days: 2)), now: now,
      ),
      '۲ روز پیش',
    );
    expect(PersianNewsDate.digits('1405/08/17'), '۱۴۰۵/۰۸/۱۷');
  });
}
