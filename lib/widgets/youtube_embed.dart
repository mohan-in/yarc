import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YouTubeEmbed extends StatefulWidget {
  const YouTubeEmbed({required this.videoId, super.key});

  final String videoId;

  @override
  State<YouTubeEmbed> createState() => _YouTubeEmbedState();
}

class _YouTubeEmbedState extends State<YouTubeEmbed> {
  late YoutubePlayerController _controller;
  late SettingsNotifier _settings;

  // Local mute state — kept in sync with the controller and SettingsNotifier.
  // We track this ourselves because YoutubePlayerValue.volume is updated
  // asynchronously by the iframe and may lag behind _controller.mute() calls.
  late bool _isMuted;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsNotifier>();
    _isMuted = _settings.muteVideosByDefault;
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        // Never autoplay — the user must tap play.
        autoPlay: false,
        mute: _isMuted,
      ),
    );
    _settings.addListener(_onSettingsChanged);
  }

  /// Applies mute/unmute instantly when the setting changes externally.
  void _onSettingsChanged() {
    if (!mounted) return;
    final shouldMute = _settings.muteVideosByDefault;
    if (shouldMute == _isMuted) return;
    setState(() => _isMuted = shouldMute);
    if (shouldMute) {
      _controller.mute();
    } else {
      _controller.unMute();
    }
  }

  /// Toggles mute on this player and persists the new preference.
  void _toggleMute() {
    final newMuted = !_isMuted;
    setState(() => _isMuted = newMuted);
    if (newMuted) {
      _controller.mute();
    } else {
      _controller.unMute();
    }
    unawaited(_settings.setMuteVideosByDefault(newMuted));
  }

  /// Pushes a dedicated fullscreen route via the root navigator.
  ///
  /// Uses the same approach as RedditVideoPlayer — a new route owns the
  /// playback in fullscreen while the inline player is paused. This avoids
  /// the YoutubePlayerBuilder orientation-trick which only works when the
  /// builder wraps the entire page, not a list item deep in the tree.
  void _enterFullScreen() {
    final startAt = _controller.value.position;
    final wasPlaying = _controller.value.isPlaying;
    _controller.pause();

    unawaited(
      Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _YouTubeFullScreenPage(
            videoId: widget.videoId,
            startAt: startAt,
            autoPlay: wasPlaying,
            isMuted: _isMuted,
          ),
        ),
      ),
    );
  }

  @override
  void deactivate() {
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    if (info.visibleFraction < 0.5 && _controller.value.isPlaying) {
      _controller.pause();
    }
    // We don't autoplay YouTube videos to avoid annoyance/data usage, user
    // must tap play. But we pause them if they scroll away.
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
        bottomActions: [
          const SizedBox(width: 8),
          const CurrentPosition(),
          const ProgressBar(isExpanded: true),
          const RemainingDuration(),
          // Mute/unmute button
          IconButton(
            icon: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _toggleMute,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: _isMuted ? 'Unmute' : 'Mute',
          ),
          // Custom fullscreen button — pushes a root-navigator route instead
          // of relying on YoutubePlayerBuilder's orientation mechanism.
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
            onPressed: _enterFullScreen,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Full screen',
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen page
// ---------------------------------------------------------------------------

/// A dedicated full-screen page for YouTube playback.
///
/// Pushed via the root navigator so it covers the entire screen regardless of
/// the home screen's layout. Locks orientation to landscape on entry and
/// restores portrait on exit.
class _YouTubeFullScreenPage extends StatefulWidget {
  const _YouTubeFullScreenPage({
    required this.videoId,
    required this.startAt,
    required this.autoPlay,
    required this.isMuted,
  });

  final String videoId;
  final Duration startAt;
  final bool autoPlay;
  final bool isMuted;

  @override
  State<_YouTubeFullScreenPage> createState() => _YouTubeFullScreenPageState();
}

class _YouTubeFullScreenPageState extends State<_YouTubeFullScreenPage> {
  late YoutubePlayerController _controller;
  late SettingsNotifier _settings;
  late bool _isMuted;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsNotifier>();
    _isMuted = widget.isMuted;

    // Lock to landscape and hide system UI for an immersive experience.
    unawaited(
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );

    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: widget.isMuted,
        startAt: widget.startAt.inSeconds,
      ),
    );
  }

  @override
  void dispose() {
    // Restore portrait orientation and system UI on exit.
    unawaited(
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    );
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      ),
    );
    _controller.dispose();
    super.dispose();
  }

  void _toggleMute() {
    final newMuted = !_isMuted;
    setState(() => _isMuted = newMuted);
    if (newMuted) {
      _controller.mute();
    } else {
      _controller.unMute();
    }
    unawaited(_settings.setMuteVideosByDefault(newMuted));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: YoutubePlayer(
            controller: _controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.red,
            bottomActions: [
              const SizedBox(width: 8),
              const CurrentPosition(),
              const ProgressBar(isExpanded: true),
              const RemainingDuration(),
              IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _toggleMute,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: _isMuted ? 'Unmute' : 'Mute',
              ),
              IconButton(
                icon: const Icon(
                  Icons.fullscreen_exit,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Exit full screen',
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
