import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_theme.dart';

class AudioPreviewPage extends StatefulWidget {
  const AudioPreviewPage({required this.localPath, super.key});
  final String localPath;
  @override
  State<AudioPreviewPage> createState() => _AudioPreviewPageState();
}

class _AudioPreviewPageState extends State<AudioPreviewPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.localPath));
    _controller.addListener(_refresh);
    _initialize();
  }

  void _refresh() { if (mounted) setState(() {}); }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('پخش صدا')),
    body: Center(child: _error != null
      ? Padding(padding: const EdgeInsets.all(24),
          child: Text('پخش صوت ممکن نیست:\n$_error', textAlign: TextAlign.center))
      : !_ready
        ? const CircularProgressIndicator()
        : Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.graphic_eq_rounded, size: 72, color: AppPalette.primary),
            const SizedBox(height: 22),
            IconButton.filled(
              onPressed: () => _controller.value.isPlaying
                ? _controller.pause() : _controller.play(),
              iconSize: 36,
              icon: Icon(_controller.value.isPlaying
                ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
            const SizedBox(height: 12),
            Text('${_controller.value.position.inSeconds} / ${_controller.value.duration.inSeconds} ثانیه',
              style: AppTypography.secondary),
          ])),
  );
}
