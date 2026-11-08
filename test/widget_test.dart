import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_news_reader/core/theme/app_theme.dart';

void main() {
  test('light theme uses Material 3 with the app surface palette', () {
    final theme = AppTheme.light;

    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, isNot(Colors.white));
    expect(theme.colorScheme.primary, isNot(Colors.transparent));
  });

  test('editorial and interface fonts map to four distinct families', () {
    expect(AppTypography.newsHeadline.fontFamily, 'Titr');
    expect(AppTypography.newsBody.fontFamily, 'Rooznameh');
    expect(AppTypography.secondary.fontFamily, 'Nazanin');
    expect(AppTypography.ui.fontFamily, 'Vazir');
    expect(AppTheme.light.appBarTheme.titleTextStyle?.fontFamily, 'Vazir');
  });
}
