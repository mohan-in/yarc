import 'package:flutter/foundation.dart';

/// Coordinates single-video-at-a-time playback across the app.
///
/// Individual `RedditVideoPlayer` widgets use `VisibilityDetector` to
/// determine their own visibility and call [play] / [stop] accordingly.
/// This notifier only tracks *which* video is currently active so that
/// two videos never play simultaneously.
class VideoAutoplayNotifier extends ChangeNotifier {
  String? _playingVideoId;

  String? get playingVideoId => _playingVideoId;

  /// Requests to play a video.
  /// If another video is playing, it will be stopped by the nature of the UI
  /// reacting to [playingVideoId] changes, but we
  /// enforce single source of truth here.
  void play(String videoId) {
    if (_playingVideoId != videoId) {
      _playingVideoId = videoId;
      notifyListeners();
    }
  }

  void stop(String videoId) {
    if (_playingVideoId == videoId) {
      _playingVideoId = null;
      notifyListeners();
    }
  }

  /// Clears the currently playing video ID.
  ///
  /// Call this when navigating to a new screen so that stale state from
  /// a previous screen does not block the first video on the new screen
  /// from initiating autoplay (the "sticky" guard in video_player.dart
  /// skips play when another video ID is already active).
  void reset() {
    if (_playingVideoId != null) {
      _playingVideoId = null;
      notifyListeners();
    }
  }
}
