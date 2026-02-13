import 'package:flutter/foundation.dart';

class VideoAutoplayNotifier extends ChangeNotifier {
  String? _playingVideoId;

  String? get playingVideoId => _playingVideoId;

  /// Notifies listeners that a scroll event has occurred.
  /// Video players should check their position when this is called.
  void notifyScroll() {
    notifyListeners();
  }

  /// Requests to play a video.
  /// If another video is playing, it will be stopped by the nature of the UI
  /// reacting to [playingVideoId] changes, but we enforce single source of truth here.
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
}
