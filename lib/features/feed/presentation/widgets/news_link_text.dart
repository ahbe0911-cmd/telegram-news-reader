import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../web/presentation/pages/in_app_browser_page.dart';

/// Renders clickable HTTP(S) links without leaving the news application.
class NewsLinkText extends StatefulWidget {
  const NewsLinkText({
    required this.text, required this.style,
    this.maxLines, this.overflow = TextOverflow.clip, super.key,
  });
  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;
  @override
  State<NewsLinkText> createState() => _NewsLinkTextState();
}

class _NewsLinkTextState extends State<NewsLinkText> {
  static final _url = RegExp(r'https?://[^\s<>"«»]+', caseSensitive: false);
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) { recognizer.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) { recognizer.dispose(); }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _url.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final candidate = match.group(0)!;
      final link = candidate.replaceFirst(RegExp(r'[.,!?،؛؟:]+$'), '');
      final suffix = candidate.substring(link.length);
      final target = Uri.tryParse(link);
      if (target != null && (target.scheme == 'http' || target.scheme == 'https')) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => InAppBrowserPage(initialUrl: link),
          ));
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: link,
          style: widget.style.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: recognizer,
        ));
      } else {
        spans.add(TextSpan(text: link));
      }
      if (suffix.isNotEmpty) spans.add(TextSpan(text: suffix));
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textDirection: TextDirection.rtl,
    );
  }
}
