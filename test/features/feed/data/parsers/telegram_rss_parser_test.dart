import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_news_reader/features/channels/domain/entities/telegram_channel.dart';
import 'package:telegram_news_reader/features/feed/data/parsers/telegram_rss_parser.dart';
import 'package:telegram_news_reader/features/feed/domain/entities/post.dart';

void main() {
  late TelegramRssParser parser;
  late TelegramChannel channel;

  setUp(() {
    parser = TelegramRssParser();
    channel = TelegramChannel(
      username: 'example_channel',
      title: 'کانال نمونه',
    );
  });

  test('parses text, date, permalink, and media from an RSS item', () {
    const xml = '''
<rss version="2.0">
  <channel>
    <item>
      <guid>https://t.me/example_channel/42</guid>
      <title>خبر نمونه</title>
      <link>https://t.me/example_channel/42</link>
      <pubDate>Fri, 07 Nov 2025 10:00:00 GMT</pubDate>
      <description><![CDATA[
        <p>متن خبر نمونه</p>
        <img src="https://cdn.example.com/photo.jpg" />
      ]]></description>
      <enclosure
        url="https://cdn.example.com/document.pdf"
        type="application/pdf" />
    </item>
  </channel>
</rss>
''';

    final posts = parser.parse(
      xml,
      channel: channel,
      feedUri: Uri.parse('https://rsshub.app/telegram/channel/example_channel'),
    );

    expect(posts, hasLength(1));
    expect(posts.single.id, 'https://t.me/example_channel/42');
    expect(posts.single.title, 'خبر نمونه');
    expect(posts.single.content, 'متن خبر نمونه');
    expect(posts.single.permalink, 'https://t.me/example_channel/42');
    expect(posts.single.publishedAt, isNotNull);
    expect(posts.single.attachments, hasLength(2));
    expect(
      posts.single.attachments
          .map((attachment) => attachment.type)
          .toSet(),
      containsAll({
        PostAttachmentType.image,
        PostAttachmentType.document,
      }),
    );
  });

  test('keeps an absent publication date null instead of inventing one', () {
    const xml = '''
<rss version="2.0">
  <channel>
    <item>
      <guid>post-without-date</guid>
      <title>بدون تاریخ</title>
      <description>متن خبر</description>
    </item>
  </channel>
</rss>
''';

    final posts = parser.parse(
      xml,
      channel: channel,
      feedUri: Uri.parse('https://rsshub.app/telegram/channel/example_channel'),
    );

    expect(posts, hasLength(1));
    expect(posts.single.publishedAt, isNull);
  });
}
