import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:yarc/notifiers/video_autoplay_notifier.dart';
import 'package:yarc/theme/theme.dart';
import 'package:yarc/utils/constants.dart';

class RedditVideoPlayer extends StatefulWidget {
  const RedditVideoPlayer({
    required this.videoUrl,
    super.key,
    this.autoPlay = false,
    this.aspectRatio = 16 / 9,
  });

  final String videoUrl;
  final bool autoPlay;
  final double aspectRatio;

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

  late VideoAutoplayNotifier _notifier;

  /// Tracks if this video overlaps the middle 50% of the screen.
  bool _overlapsSafeZone = false;

  /// Tracks the visible fraction.
  /// If 0, the video is completely off-screen (e.g. tab switched).
  double _visibleFraction = 0;

  /// Listener for continuous scroll updates
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    _playerId = widget.videoUrl;
    _notifier = context.read<VideoAutoplayNotifier>();
    _notifier.addListener(_onNotifierUpdate);
    // updateInterval is set globally in main.dart — no per-instance override.
    unawaited(_initializePlayer());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    if (_scrollPosition != scrollable?.position) {
      _scrollPosition?.removeListener(_evaluateAutoplay);
      _scrollPosition = scrollable?.position;
      _scrollPosition?.addListener(_evaluateAutoplay);
    }
  }

  /// Called when the notifier's `playingVideoId` changes.
  /// Handles three cases: another video took over (pause us), we are
  /// the active video (resume if needed), or nobody is playing and
  /// we are visible (claim playback).
  void _onNotifierUpdate() {
    if (!_isInit ||
        _chewieController == null ||
        !mounted ||
        _isFullScreenActive) {
      return;
    }

    final activeId = _notifier.playingVideoId;

    if (activeId != null &&
        activeId != _playerId &&
        _chewieController!.isPlaying) {
      // Another video claimed playback — pause us.
      unawaited(_chewieController!.pause());
    } else if (activeId == _playerId &&
        _overlapsSafeZone &&
        widget.autoPlay &&
        !_isFullScreenActive &&
        !_chewieController!.isPlaying) {
      // We are the active video and visible — resume.
      unawaited(_chewieController!.play());
    } else if (activeId == null &&
        _overlapsSafeZone &&
        widget.autoPlay &&
        !_isFullScreenActive) {
      // No video is currently playing and we are visible — claim it.
      // This handles the case where VisibilityDetector callbacks fire
      // out of order: the incoming video's callback ran before the
      // outgoing video released ownership, so _tryPlay() was a no-op.
      // Now that the outgoing video has stopped, we get notified here
      // and can claim playback.
      _tryPlay();
    }
  }

  @override
  void didUpdateWidget(covariant RedditVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPlay != oldWidget.autoPlay) {
      if (widget.autoPlay && _overlapsSafeZone) {
        _tryPlay();
      } else if (!widget.autoPlay) {
        _tryPause();
      }
    }
  }

  /// Checks if the video overlaps the middle 50% of the viewport.
  bool _isInSafeZone() {
    if (!mounted) {
      return false;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return false;
    }

    try {
      final size = renderObject.size;
      final position = renderObject.localToGlobal(Offset.zero);
      final top = position.dy;
      final bottom = top + size.height;

      // Middle 50% of the screen
      final screenHeight = MediaQuery.sizeOf(context).height;
      final safeZoneTop = screenHeight * 0.25;
      final safeZoneBottom = screenHeight * 0.75;

      return top < safeZoneBottom && bottom > safeZoneTop;
    } on Object catch (_) {
      return false;
    }
  }

  /// Handles [VisibilityDetector] updates.
  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) {
      return;
    }

    _visibleFraction = info.visibleFraction;
    _evaluateAutoplay();
  }

  /// Evaluates autoplay conditions based on current scroll position
  /// and visibility.
  void _evaluateAutoplay() {
    if (!mounted ||
        !_isInit ||
        _chewieController == null ||
        _isFullScreenActive) {
      return;
    }

    // A video is only in the safe zone if it's both positionally inside it,
    // and not entirely hidden by route/tab changes.
    final currentlyInSafeZone = _visibleFraction > 0 && _isInSafeZone();

    if (currentlyInSafeZone != _overlapsSafeZone) {
      _overlapsSafeZone = currentlyInSafeZone;
    }

    if (_overlapsSafeZone && widget.autoPlay) {
      _tryPlay();
    } else if (!_overlapsSafeZone) {
      _tryPause();
    }
  }

  /// Claims playback ownership and starts playing.
  ///
  /// If nobody is playing, or if we already own playback, we play.
  /// If another video is currently playing, we do NOT steal playback.
  /// We wait for it to leave the safe zone, at which point it releases
  /// ownership and [_onNotifierUpdate] will trigger us to start.
  void _tryPlay() {
    if (!_isInit || _chewieController == null || _isFullScreenActive) {
      return;
    }

    final activeId = _notifier.playingVideoId;

    if (activeId == null || activeId == _playerId) {
      _notifier.play(_playerId);
      if (!_chewieController!.isPlaying) {
        unawaited(_chewieController!.play());
      }
    }
  }

  /// Pauses playback and releases ownership if we hold it.
  void _tryPause() {
    if (_chewieController != null && _chewieController!.isPlaying) {
      unawaited(_chewieController!.pause());
    }
    _notifier.stop(_playerId);
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    try {
      await _videoPlayerController.initialize();
      if (!mounted) {
        return;
      }

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
                Text(
                  errorMessage,
                  style: TextStyle(
                    color:
                        Theme.of(
                          context,
                        ).extension<MediaViewerTheme>()?.labelColor ??
                        Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      );

      setState(() {
        _isInit = true;
      });

      // If we are already visible (e.g. first video in feed on load),
      // kick off autoplay immediately. VisibilityDetector will fire shortly
      // but this covers the initialization race.
      if (widget.autoPlay && _overlapsSafeZone && mounted) {
        _tryPlay();
      }
    } on Object catch (_) {}
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_evaluateAutoplay);
    _notifier.removeListener(_onNotifierUpdate);
    // Always stop playback and release ownership on dispose.
    // This is critical — without it, a video scrolled far off-screen
    // (whose widget is disposed by the list) continues to hold
    // playingVideoId and blocks all other videos from playing.
    if (_chewieController != null && _chewieController!.isPlaying) {
      unawaited(_chewieController!.pause());
    }
    _notifier.stop(_playerId);
    unawaited(_videoPlayerController.dispose());
    _chewieController?.dispose();
    super.dispose();
  }

  void _enterFullScreen() {
    _isFullScreenActive = true;

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

    unawaited(
      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                body: SafeArea(
                  child: Center(
                    child: Chewie(controller: fullScreenController),
                  ),
                ),
              ),
            ),
          )
          .then((_) {
            _isFullScreenActive = false;
            fullScreenController.dispose();
            // After returning from fullscreen, re-evaluate visibility.
            if (mounted && widget.autoPlay && _overlapsSafeZone) {
              _tryPlay();
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit || _chewieController == null) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: const ColoredBox(
          color: Colors.black12,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final nativeAspectRatio = _videoPlayerController.value.aspectRatio;
    final viewportHeight = MediaQuery.of(context).size.height;
    final maxHeight = viewportHeight * kVideoMaxHeightFraction;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate the natural height of the video at screen width.
    final naturalHeight = screenWidth / nativeAspectRatio;

    // If the video would be taller than our cap, constrain it.
    final effectiveHeight = naturalHeight > maxHeight ? maxHeight : null;

    final Widget videoWidget = GestureDetector(
      onTap: _enterFullScreen,
      child: effectiveHeight != null
          ? SizedBox(
              width: screenWidth,
              height: effectiveHeight,
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: screenWidth,
                  height: naturalHeight,
                  child: Chewie(controller: _chewieController!),
                ),
              ),
            )
          : AspectRatio(
              aspectRatio: nativeAspectRatio,
              child: Chewie(controller: _chewieController!),
            ),
    );

    return VisibilityDetector(
      key: ValueKey('video_$_playerId'),
      onVisibilityChanged: _onVisibilityChanged,
      child: videoWidget,
    );
  }
}
