import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';

class PdfViewerPage extends StatelessWidget {
  const PdfViewerPage({
    required this.url,
    this.localPath,
    this.fileName,
    super.key,
  });

  final String url;
  final String? localPath;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final hasLocalFile = localPath != null && File(localPath!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fileName?.isNotEmpty == true ? fileName! : 'مطالعه سند PDF',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: hasLocalFile
          ? PDF(
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
            ).fromPath(localPath!)
          : PDF(
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
            ).cachedFromUrl(
              url,
              placeholder: (progress) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text('دریافت فایل: ${progress.toStringAsFixed(0)}٪'),
                  ],
                ),
              ),
              errorWidget: (error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'باز کردن فایل PDF ممکن نیست.\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
    );
  }
}
