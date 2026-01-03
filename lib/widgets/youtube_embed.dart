import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';

class YouTubeEmbed extends StatefulWidget {
  final String videoId;

  const YouTubeEmbed({super.key, required this.videoId});

  @override
  State<YouTubeEmbed> createState() => _YouTubeEmbedState();
}

class _YouTubeEmbedState extends State<YouTubeEmbed> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        mute: false,
        autoPlay: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: false,
        enableCaption: true,
      ),
    )..addListener(_listener);
  }

  void _listener() {
    if (_isPlayerReady && mounted && !_controller.value.isFullScreen) {
      // Logic for state changes if needed
    }
  }

  @override
  void deactivate() {
    // Pauses video while navigating to next page.
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    if (info.visibleFraction < 0.5) {
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
    }
    // We don't autoplay YouTube videos to avoid annoyance/data usage, user must tap play.
    // But we pause them if they scroll away.
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('youtube-${widget.videoId}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        onReady: () {
          _isPlayerReady = true;
        },
      ),
    );
  }
}
