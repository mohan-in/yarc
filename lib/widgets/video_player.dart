import 'dart:async';
import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/notifiers/video_autoplay_notifier.dart';
import 'package:yarc/theme/theme.dart';
import 'package:yarc/utils/constants.dart';
import 'package:yarc/utils/image_utils.dart';

class RedditVideoPlayer extends StatefulWidget {
  const RedditVideoPlayer({
    required this.videoUrl,
    super.key,
    this.autoPlay = false,
    this.aspectRatio = 16 / 9,
    this.thumbnailUrl,
  });

  final String videoUrl;
  final bool autoPlay;
  final double aspectRatio;
  final String? thumbnailUrl;

  @override
  State<RedditVideoPlayer> createState() => _RedditVideoPlayerState();
}

class _RedditVideoPlayerState extends State<RedditVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInit = false;
  bool _isInitializing = false;
  bool _userTappedToPlay = false;

  // Unique ID for this player instance, stable across rebuilds.
  // Using a per-instance key (not the URL) avoids ID collisions when two
  // posts share the same video URL (e.g. crossposts).
  late final String _playerId;

  late VideoAutoplayNotifier _notifier;
  late SettingsNotifier _settings;

  /// Tracks if this video overlaps the middle 50% of the screen.
  bool _overlapsSafeZone = false;

  /// Tracks the visible fraction.
  /// If 0, the video is completely off-screen (e.g. tab switched).
  double _visibleFraction = 0;

  /// Listener for continuous scroll updates
  ScrollPosition? _scrollPosition;

  bool _hasVideoListener = false;

  double _lastVolume = 1;

  void _onVideoControllerUpdate() {
    if (mounted && _videoPlayerController != null) {
      final currentVolume = _videoPlayerController!.value.volume;
      if (currentVolume != _lastVolume) {
        _lastVolume = currentVolume;
        final isMuted = currentVolume == 0;
        if (_settings.muteVideosByDefault != isMuted) {
          unawaited(_settings.setMuteVideosByDefault(isMuted));
        }
      }
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _playerId = '${identityHashCode(this)}_${widget.videoUrl.hashCode}';
    _notifier = context.read<VideoAutoplayNotifier>();
    _notifier.addListener(_onNotifierUpdate);
    _settings = context.read<SettingsNotifier>();
    _settings.addListener(_onSettingsChanged);
    _lastVolume = _settings.muteVideosByDefault ? 0.0 : 1.0;
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

  /// Called when [SettingsNotifier] changes — applies mute/unmute instantly.
  void _onSettingsChanged() {
    if (!_isInit || !mounted || _videoPlayerController == null) return;
    final targetVolume = _settings.muteVideosByDefault ? 0.0 : 1.0;
    unawaited(_videoPlayerController!.setVolume(targetVolume));
  }

  /// Called when the notifier's `playingVideoId` changes.
  void _onNotifierUpdate() {
    final isFullScreen = _chewieController?.isFullScreen ?? false;
    if (!_isInit || _chewieController == null || !mounted || isFullScreen) {
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
        (widget.autoPlay || _userTappedToPlay) &&
        !isFullScreen &&
        !_chewieController!.isPlaying) {
      // We are the active video and visible — resume.
      unawaited(_chewieController!.play());
    } else if (activeId == null &&
        _overlapsSafeZone &&
        (widget.autoPlay || _userTappedToPlay) &&
        !isFullScreen) {
      _tryPlay();
    }
  }

  @override
  void didUpdateWidget(covariant RedditVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPlay != oldWidget.autoPlay) {
      if (widget.autoPlay && _overlapsSafeZone) {
        if (!_isInit && !_isInitializing) {
          unawaited(_initializePlayer(andPlay: true));
        } else if (_isInit) {
          _tryPlay();
        }
      } else if (!widget.autoPlay && !_userTappedToPlay) {
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
    } on Exception catch (e) {
      developer.log(
        'Failed to calculate safe zone: $e',
        name: 'RedditVideoPlayer',
      );
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
    final isFullScreen = _chewieController?.isFullScreen ?? false;
    if (!mounted || isFullScreen) {
      return;
    }

    // A video is only in the safe zone if it's both positionally inside it,
    // and not entirely hidden by route/tab changes.
    final currentlyInSafeZone = _visibleFraction > 0 && _isInSafeZone();

    if (currentlyInSafeZone != _overlapsSafeZone) {
      _overlapsSafeZone = currentlyInSafeZone;
    }

    if (_overlapsSafeZone && (widget.autoPlay || _userTappedToPlay)) {
      if (!_isInit && !_isInitializing) {
        unawaited(_initializePlayer(andPlay: true));
      } else if (_isInit) {
        _tryPlay();
      }
    } else if (!_overlapsSafeZone && _isInit) {
      _tryPause();
    }
  }

  /// Claims playback ownership and starts playing.
  void _tryPlay() {
    final isFullScreen = _chewieController?.isFullScreen ?? false;
    if (!_isInit || _chewieController == null || isFullScreen) {
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

  Future<void> _initializePlayer({bool andPlay = false}) async {
    if (_isInitializing || _isInit) {
      return;
    }
    _isInitializing = true;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _videoPlayerController = controller;

    try {
      await controller.initialize();
      // Apply mute setting immediately after initialization.
      if (_settings.muteVideosByDefault) {
        await controller.setVolume(0);
      }
      if (!mounted) {
        return;
      }
      controller.addListener(_onVideoControllerUpdate);
      _hasVideoListener = true;

      _chewieController = ChewieController(
        videoPlayerController: controller,
        aspectRatio: controller.value.aspectRatio,
        showControlsOnInitialize: false,
        deviceOrientationsOnEnterFullScreen: const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: const [
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
        _isInitializing = false;
      });

      if ((andPlay || (widget.autoPlay && _overlapsSafeZone)) && mounted) {
        _tryPlay();
      }
    } on Exception catch (e) {
      developer.log(
        'Failed to initialize video player: $e',
        name: 'RedditVideoPlayer',
      );
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_evaluateAutoplay);
    _notifier.removeListener(_onNotifierUpdate);
    _settings.removeListener(_onSettingsChanged);
    if (_hasVideoListener && _videoPlayerController != null) {
      _videoPlayerController!.removeListener(_onVideoControllerUpdate);
    }
    if (_chewieController != null && _chewieController!.isPlaying) {
      unawaited(_chewieController!.pause());
    }
    _notifier.stop(_playerId);
    if (_videoPlayerController != null) {
      unawaited(_videoPlayerController!.dispose());
    }
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit || _chewieController == null) {
      final placeholder = widget.thumbnailUrl != null
          ? GestureDetector(
              onTap: () {
                setState(() {
                  _userTappedToPlay = true;
                });
                unawaited(_initializePlayer(andPlay: true));
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: widget.aspectRatio,
                    child: CachedNetworkImage(
                      imageUrl: ImageUtils.getCorsUrl(widget.thumbnailUrl!),
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const ColoredBox(color: Colors.black12),
                      errorWidget: (context, url, error) => const ColoredBox(
                        color: Colors.black12,
                        child: Icon(
                          Icons.movie_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  if (_isInitializing)
                    const Center(child: CircularProgressIndicator())
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                ],
              ),
            )
          : AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: ColoredBox(
                color: Colors.black12,
                child: Center(
                  child: _isInitializing
                      ? const CircularProgressIndicator()
                      : IconButton(
                          iconSize: 48,
                          icon: const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              _userTappedToPlay = true;
                            });
                            unawaited(_initializePlayer(andPlay: true));
                          },
                        ),
                ),
              ),
            );

      return VisibilityDetector(
        key: ValueKey('video_$_playerId'),
        onVisibilityChanged: _onVisibilityChanged,
        child: placeholder,
      );
    }

    final nativeAspectRatio = _videoPlayerController!.value.aspectRatio;
    final viewportHeight = MediaQuery.of(context).size.height;
    final maxHeight = viewportHeight * kVideoMaxHeightFraction;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate the natural height of the video at screen width.
    final naturalHeight = screenWidth / nativeAspectRatio;

    // If the video would be taller than our cap, constrain it.
    final effectiveHeight = naturalHeight > maxHeight ? maxHeight : null;

    final Widget videoWidget = effectiveHeight != null
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
          );

    return VisibilityDetector(
      key: ValueKey('video_$_playerId'),
      onVisibilityChanged: _onVisibilityChanged,
      child: videoWidget,
    );
  }
}
