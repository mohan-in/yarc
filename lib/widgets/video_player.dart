import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:provider/provider.dart';
import '../notifiers/video_autoplay_notifier.dart';

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
  bool _isFullScreenActive = false;
  // Unique ID for this player instance to coordinate with notifier
  late final String _playerId;

  @override
  void initState() {
    super.initState();
    _playerId = widget.videoUrl;
    _initializePlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.autoPlay) {
      final notifier = context.watch<VideoAutoplayNotifier>();
      _checkAutoplay(notifier);
    }
  }

  void _checkAutoplay(VideoAutoplayNotifier notifier) {
    if (!_isInit || _chewieController == null || _isFullScreenActive) return;

    // Post-frame callback to ensure layout is ready for coordinate check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) return;

      final viewportHeight = MediaQuery.of(context).size.height;
      try {
        final position = renderObject.localToGlobal(Offset.zero);
        final top = position.dy;
        final center = top + (renderObject.size.height / 2);

        // "Middle 70%" zone
        final safeZoneTop = viewportHeight * 0.15;
        final safeZoneBottom = viewportHeight * 0.85;

        final isInZone = center >= safeZoneTop && center <= safeZoneBottom;

        if (isInZone) {
          // If in zone, we should be playing unless someone else already is
          if (notifier.playingVideoId == null) {
            notifier.play(_playerId);
          } else if (notifier.playingVideoId == _playerId) {
            if (!_chewieController!.isPlaying) {
              _chewieController!.play();
            }
          }
          // If someone else is playing, we wait (sticky behavior)
        } else {
          // If out of zone, we must stop if we are the one playing
          if (notifier.playingVideoId == _playerId) {
            notifier.stop(_playerId);
          }
          if (_chewieController!.isPlaying) {
            _chewieController!.pause();
          }
        }
      } catch (e) {
        // Handle layout errors (e.g. during navigation)
      }
    });
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
        showControls: false,
        showControlsOnInitialize: false,
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

      // Initial check in case we load directly into view
      if (widget.autoPlay && mounted) {
        // Trigger a check via the notifier logic
        // We can't access context.read inside async init easily without mounted check
        // relying on didChangeDependencies or scrolling to trigger
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    // If we were playing, stop
    // We can't access context here easily if unmounted, but ideally notifier cleans up or new player takes over
    super.dispose();
  }

  void _enterFullScreen() {
    _isFullScreenActive = true;
    // Tell notifier to stop managing us for a moment (or just let it be)
    // Actually, if we go fullscreen, we probably want to pause the specific inline player logic
    // But Chewie handles fullscreen by creating a new controller usually or reparenting.
    // Let's just pause our inline logic.

    final fullScreenController = ChewieController(
      videoPlayerController: _videoPlayerController,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      autoPlay: true,
      looping: true,
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
          // Re-trigger auth check?
          if (mounted && widget.autoPlay) {
            context.read<VideoAutoplayNotifier>().notifyScroll();
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

    return GestureDetector(
      onTap: _enterFullScreen,
      child: AspectRatio(
        aspectRatio: _videoPlayerController.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
