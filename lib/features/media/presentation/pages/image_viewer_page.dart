import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({
    required this.url,
    this.localPath,
    super.key,
  });

  final String url;
  final String? localPath;

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object> imageProvider = localPath != null
        ? FileImage(File(localPath!))
        : CachedNetworkImageProvider(url);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('نمایش تصویر'),
      ),
      body: PhotoView(
        imageProvider: imageProvider,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text(
            'تصویر قابل نمایش نیست.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
