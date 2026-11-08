import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/formatters/persian_news_date.dart';
import '../../../../core/theme/app_theme.dart';

/// Audio-only full-screen player. The controller is created lazily and is
/// always disposed when this route closes; app backgrounding pauses playback.
class AudioPreviewPage extends StatefulWidget {
  const AudioPreviewPage({this.localPath, this.url, super.key})
      : assert(localPath != null || url != null);

  final String? localPath;
  final String? url;

  @override
  State<AudioPreviewPage> createState() => _AudioPreviewPageState();
}

class _AudioPreviewPageState extends State<AudioPreviewPage>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;
  double? _dragPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = widget.localPath != null
        ? VideoPlayerController.file(File(widget.localPath!))
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
    _controller.addListener(_refresh);
    _initialize();
  }

  void _refresh() {
    if (mounted && _ready) setState(() {});
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _controller.value.isInitialized && _controller.value.isPlaying) {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  String _clock(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return PersianNewsDate.digits('$minutes:$seconds');
  }

  @override
  Widget build(BuildContext context) {
    final duration = _controller.value.isInitialized
        ? _controller.value.duration : Duration.zero;
    final position = _controller.value.isInitialized
        ? _controller.value.position : Duration.zero;
    final maxMs = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final currentMs = (_dragPosition ?? position.inMilliseconds.toDouble())
        .clamp(0.0, maxMs).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('پخش صدا')),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('پخش صوت ممکن نیست:\n$_error',
                    textAlign: TextAlign.center),
              )
            : !_ready
                ? const CircularProgressIndicator()
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 160,
                          width: 160,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppPalette.primary, AppPalette.violet],
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.primary.withValues(alpha: 0.2),
                                offset: const Offset(0, 12),
                                blurRadius: 25,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            size: 86,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'پخش فایل صوتی',
                          style: AppTypography.ui.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Slider(
                          value: currentMs,
                          min: 0,
                          max: maxMs,
                          onChanged: duration > Duration.zero
                              ? (value) => setState(() => _dragPosition = value)
                              : null,
                          onChangeEnd: (value) async {
                            setState(() => _dragPosition = null);
                            await _controller.seekTo(
                              Duration(milliseconds: value.round()),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Text(_clock(Duration(milliseconds: currentMs.round())),
                                  style: AppTypography.secondary),
                              const Spacer(),
                              Text(_clock(duration),
                                  style: AppTypography.secondary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        IconButton.filled(
                          iconSize: 38,
                          tooltip: _controller.value.isPlaying ? 'توقف' : 'پخش',
                          onPressed: () => _controller.value.isPlaying
                              ? _controller.pause() : _controller.play(),
                          icon: Icon(_controller.value.isPlaying
                              ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
