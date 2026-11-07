import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({
    required this.url,
    this.localPath,
    this.thumbnailUrl,
    super.key,
  });

  final String url;
  final String? localPath;
  final String? thumbnailUrl;

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer>
    with WidgetsBindingObserver {
  late final VideoPlayerController _videoController;
  ChewieController? _chewieController;
  Object? _initializationError;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _videoController = widget.localPath != null
        ? VideoPlayerController.file(File(widget.localPath!))
        : VideoPlayerController.networkUrl(Uri.parse(widget.url));

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _videoController.initialize();
      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio > 0
            ? _videoController.value.aspectRatio
            : 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
      );

      setState(() => _initialized = true);
    } catch (error) {
      if (mounted) setState(() => _initializationError = error);
    }
  }

  void _handleVisibility(VisibilityInfo info) {
    if (info.visibleFraction < 0.35 &&
        _videoController.value.isInitialized &&
        _videoController.value.isPlaying) {
      _videoController.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _videoController.value.isInitialized &&
        _videoController.value.isPlaying) {
      _videoController.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return VisibilityDetector(
      key: ObjectKey(this),
      onVisibilityChanged: _handleVisibility,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: _initialized &&
                  _videoController.value.aspectRatio > 0
              ? _videoController.value.aspectRatio
              : 16 / 9,
          child: ColoredBox(
            color: Colors.black,
            child: _initializationError != null
                ? Center(
                    child: Text(
                      'پخش ویدئو ممکن نیست.',
                      style: TextStyle(color: colors.onInverseSurface),
                    ),
                  )
                : !_initialized || _chewieController == null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          if (widget.thumbnailUrl != null)
                            Image.network(
                              widget.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Chewie(controller: _chewieController!),
          ),
        ),
      ),
    );
  }
}
