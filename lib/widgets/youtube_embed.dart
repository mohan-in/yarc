import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YouTubeEmbed extends StatefulWidget {
  const YouTubeEmbed({required this.videoId, super.key});

  final String videoId;

  @override
  State<YouTubeEmbed> createState() => _YouTubeEmbedState();
}

class _YouTubeEmbedState extends State<YouTubeEmbed> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(initialVideoId: widget.videoId);
  }

  @override
  void deactivate() {
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) {
      return;
    }
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
      key: ValueKey('youtube_${widget.videoId}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        onReady: () {},
      ),
    );
  }
}
