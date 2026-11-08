import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/save_to_device_button.dart';

/// Internal fallback for plain-text documents and unsupported binary files.
class LocalDocumentPreviewPage extends StatefulWidget {
  const LocalDocumentPreviewPage({required this.path, this.fileName, super.key});
  final String path;
  final String? fileName;
  @override
  State<LocalDocumentPreviewPage> createState() => _LocalDocumentPreviewPageState();
}

class _LocalDocumentPreviewPageState extends State<LocalDocumentPreviewPage> {
  String? _text;
  String? _message;
  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
      final file = File(widget.path);
      final size = await file.length();
      final ext = widget.path.split('.').last.toLowerCase();
      if (const ['txt', 'log', 'md', 'csv', 'json', 'xml', 'html', 'yaml', 'yml'].contains(ext)) {
        if (size > 1024 * 1024) {
          _message = 'این فایل متنی بزرگ‌تر از یک مگابایت است.';
        } else {
          _text = await file.readAsString();
        }
      } else {
        _message = 'پیش‌نمایش داخلی برای این نوع فایل موجود نیست؛ فایل روی گوشی ذخیره شده است.';
      }
    } catch (error) {
      _message = 'خواندن فایل ممکن نیست: $error';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.fileName ?? 'فایل دانلودشده',
        maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [SaveToDeviceButton(
        localPath: widget.path,
        fileName: widget.fileName ?? widget.path.split('/').last,
      )],
    ),
    body: _text != null
        ? ListView(padding: const EdgeInsets.all(18),
            children: [SelectableText(_text!, style: AppTypography.newsBody)])
        : Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(_message ?? 'در حال بررسی فایل…',
              textAlign: TextAlign.center))),
  );
}
