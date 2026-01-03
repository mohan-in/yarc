import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';

class RedditVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final double aspectRatio;

  const RedditVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.aspectRatio = 16 / 9,
  });

  @override
  State<RedditVideoPlayer> createState() => _RedditVideoPlayerState();
}

class _RedditVideoPlayerState extends State<RedditVideoPlayer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInit = false;
  bool _isVisible = false;
  bool _isFullScreenActive = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    try {
      await _videoPlayerController.initialize();
      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoPlay: false,
        looping: true,
        showControls: false, // Hide controls inline to behave like an image
        showControlsOnInitialize: false,
        allowFullScreen: true,
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
        placeholder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(height: 8),
                Text(errorMessage, style: const TextStyle(color: Colors.white)),
              ],
            ),
          );
        },
      );

      setState(() {
        _isInit = true;
      });

      if (widget.autoPlay && _isVisible) {
        _chewieController?.play();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted || !_isInit || _chewieController == null) return;
    // Don't pause if we are in full screen mode (native video player active)
    if (_isFullScreenActive) return;

    if (info.visibleFraction > 0.6) {
      _isVisible = true; // Mark as visible
      if (widget.autoPlay && !_chewieController!.isPlaying) {
        _chewieController!.play();
      }
    } else {
      _isVisible = false;
      if (widget.autoPlay && _chewieController!.isPlaying) {
        _chewieController!.pause();
      }
    }
  }

  void _enterFullScreen() {
    _isFullScreenActive = true;
    final fullScreenController = ChewieController(
      videoPlayerController: _videoPlayerController,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      autoPlay: true,
      looping: true,
      showControls: true,
      deviceOrientationsOnEnterFullScreen: [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Center(child: Chewie(controller: fullScreenController)),
              ),
            ),
          ),
        )
        .then((_) {
          _isFullScreenActive = false;
          fullScreenController.dispose();
          // Ensure inline player state is consistent if needed
          if (mounted && widget.autoPlay && _isVisible) {
            _chewieController?.play();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit || _chewieController == null) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Container(
          color: Colors.black12,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Only wrap with VisibilityDetector if autoPlay is enabled to handle feed behavior
    if (widget.autoPlay) {
      return VisibilityDetector(
        key: Key(widget.videoUrl),
        onVisibilityChanged: _handleVisibilityChanged,
        child: GestureDetector(
          onTap: _enterFullScreen,
          child: AspectRatio(
            aspectRatio: _videoPlayerController.value.aspectRatio,
            child: Stack(children: [Chewie(controller: _chewieController!)]),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _enterFullScreen,
      child: AspectRatio(
        aspectRatio: _videoPlayerController.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
