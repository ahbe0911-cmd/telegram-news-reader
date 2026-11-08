import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_news_reader/core/theme/app_theme.dart';
import 'package:telegram_news_reader/features/feed/domain/entities/post.dart';
import 'package:telegram_news_reader/features/feed/presentation/widgets/post_card.dart';
import 'package:telegram_news_reader/features/feed/presentation/widgets/news_link_text.dart';

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

  testWidgets('news preview is compact and expands when tapped', (tester) async {
    final post = Post(
      id: 'test:1',
      channelUsername: 'news',
      channelTitle: 'اخبار',
      title: 'یک تیتر آزمایشی',
      content: List.filled(40, 'متن خبر').join(' '),
      sourceUrl: 'https://example.com',
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(
        child: PostCard(post: post, isBookmarked: false),
      )),
    ));
    final texts = tester.widgetList<NewsLinkText>(find.byType(NewsLinkText)).toList();
    expect(texts.length, 2);
    expect(texts.last.maxLines, 2);
    await tester.tap(find.text('ادامه خبر'));
    await tester.pump();
    final expanded = tester.widgetList<NewsLinkText>(find.byType(NewsLinkText)).toList();
    expect(expanded.last.maxLines, isNull);
  });
}
