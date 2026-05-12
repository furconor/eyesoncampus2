import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class BackgroundMedia extends StatefulWidget {
  final String url;
  final double opacity;
  final VoidCallback? onVideoEnd;

  const BackgroundMedia({
    super.key,
    required this.url,
    this.opacity = 0.3,
    this.onVideoEnd,
  });

  static bool isVideo(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m4v');
  }

  @override
  State<BackgroundMedia> createState() => _BackgroundMediaState();
}

class _BackgroundMediaState extends State<BackgroundMedia> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _endFired = false;

  @override
  void initState() {
    super.initState();
    if (BackgroundMedia.isVideo(widget.url)) _initVideo();
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await ctrl.initialize();
    ctrl.setVolume(0);
    ctrl.setLooping(widget.onVideoEnd == null);
    ctrl.addListener(_onTick);
    ctrl.play();
    if (mounted) setState(() { _controller = ctrl; _initialized = true; });
  }

  void _onTick() {
    final ctrl = _controller;
    if (ctrl == null || _endFired) return;
    final dur = ctrl.value.duration;
    final pos = ctrl.value.position;
    if (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 300)) {
      _endFired = true;
      widget.onVideoEnd?.call();
    }
  }

  @override
  void didUpdateWidget(BackgroundMedia old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _controller?.removeListener(_onTick);
      _controller?.dispose();
      _controller = null;
      _initialized = false;
      _endFired = false;
      if (BackgroundMedia.isVideo(widget.url)) _initVideo();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (BackgroundMedia.isVideo(widget.url)) {
      if (!_initialized || _controller == null) {
        return const ColoredBox(color: Colors.black);
      }
      return Opacity(
        opacity: widget.opacity,
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      );
    }
    return Image.network(
      widget.url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      opacity: AlwaysStoppedAnimation(widget.opacity),
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
