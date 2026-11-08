import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../widgets/save_to_device_button.dart';

/// Full-screen lightbox, with native pan/zoom and one-finger swipe-down exit.
/// Gesture tracking is passive so it never steals pinch gestures.
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    required this.url,
    this.localPath,
    this.fileName,
    super.key,
  });

  final String url;
  final String? localPath;
  final String? fileName;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final TransformationController _transform = TransformationController();
  final Set<int> _touches = <int>{};
  Offset? _start;
  Offset? _end;
  bool _multitouch = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (_touches.isEmpty) {
      _start = event.position;
      _end = event.position;
      _multitouch = false;
    }
    _touches.add(event.pointer);
    if (_touches.length > 1) _multitouch = true;
  }

  void _move(PointerMoveEvent event) {
    if (_touches.contains(event.pointer) && !_multitouch) {
      _end = event.position;
    }
  }

  void _up(PointerEvent event) {
    if (!_touches.remove(event.pointer)) return;
    if (_touches.isNotEmpty) return;
    final start = _start;
    final end = _end;
    final isAtNormalScale = _transform.value.getMaxScaleOnAxis() <= 1.05;
    if (!_multitouch && start != null && end != null && isAtNormalScale) {
      final delta = end - start;
      // Keep tiny scroll movements and horizontal pans from dismissing.
      if (delta.dy > 125 && delta.dy > delta.dx.abs() * 1.5) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    }
    _start = null;
    _end = null;
    _multitouch = false;
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.localPath;
    final ImageProvider<Object> provider = local != null && local.isNotEmpty
        ? FileImage(File(local))
        : CachedNetworkImageProvider(widget.url);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 5,
              panEnabled: true,
              scaleEnabled: true,
              boundaryMargin: const EdgeInsets.all(64),
              child: SizedBox.expand(
                child: Image(
                  image: provider,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  loadingBuilder: (context, image, progress) {
                    if (progress == null) return image;
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        value: progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text(
                      'تصویر قابل نمایش نیست.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'بستن تصویر',
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black.withValues(alpha: 0.55),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const Spacer(),
                    SaveToDeviceButton(
                      localPath: widget.localPath,
                      url: widget.localPath == null ? widget.url : null,
                      fileName: widget.fileName ?? 'image.jpg',
                      mimeType: 'image/jpeg',
                      foregroundColor: Colors.white,
                    ),
                    Text(
                      'برای بزرگ‌نمایی از دو انگشت استفاده کنید',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.83),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
