// Positional boolean parameters are clear here given the setter naming.
// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yarc/models/feed_sort.dart';

class SettingsNotifier extends ChangeNotifier {
  /// Initialises settings by reading persisted values synchronously.
  ///
  /// [_loadSettings] only populates fields; it does NOT call
  /// [notifyListeners] because no listeners can be registered yet during
  /// construction. Calling [notifyListeners] in a constructor body is a
  /// ChangeNotifier anti-pattern that triggers assertion warnings in debug
  /// mode and is a conceptual no-op.
  SettingsNotifier(this._prefs) {
    _loadSettings();
  }

  final SharedPreferences _prefs;

  static const _kAutoPlayVideosKey = 'auto_play_videos';
  static const _kMuteVideosKey = 'mute_videos_by_default';
  static const _kUseSystemBrowserKey = 'use_system_browser';
  static const _kHideReadPostsKey = 'hide_read_posts';
  static const _kHideNsfwKey = 'hide_nsfw';
  static const _kDefaultSortKey = 'default_feed_sort';
  static const _kRequireBiometricForNsfwKey = 'require_biometric_for_nsfw';

  bool _autoPlayVideos = true;
  bool _muteVideosByDefault = true;
  bool _useSystemBrowser = false;
  bool _hideReadPosts = false;
  bool _hideNsfw = true;
  bool _requireBiometricForNsfw = false;
  FeedSort _defaultSort = FeedSort.best;

  bool get autoPlayVideos => _autoPlayVideos;
  bool get muteVideosByDefault => _muteVideosByDefault;
  bool get useSystemBrowser => _useSystemBrowser;
  bool get hideReadPosts => _hideReadPosts;
  bool get hideNsfw => _hideNsfw;
  bool get requireBiometricForNsfw => _requireBiometricForNsfw;
  FeedSort get defaultSort => _defaultSort;

  /// Populates fields from [SharedPreferences]. Called only from the
  /// constructor, so [notifyListeners] is intentionally omitted here —
  /// no listeners exist yet and calling it would be a no-op that causes
  /// assertion warnings in debug builds.
  void _loadSettings() {
    _autoPlayVideos = _prefs.getBool(_kAutoPlayVideosKey) ?? true;
    _muteVideosByDefault = _prefs.getBool(_kMuteVideosKey) ?? true;
    _useSystemBrowser = _prefs.getBool(_kUseSystemBrowserKey) ?? false;
    _hideReadPosts = _prefs.getBool(_kHideReadPostsKey) ?? false;
    _hideNsfw = _prefs.getBool(_kHideNsfwKey) ?? true;
    _requireBiometricForNsfw =
        _prefs.getBool(_kRequireBiometricForNsfwKey) ?? false;

    final sortString = _prefs.getString(_kDefaultSortKey);
    if (sortString != null) {
      _defaultSort = FeedSort.values.firstWhere(
        (s) => s.name == sortString,
        orElse: () => FeedSort.best,
      );
    }
    // Do NOT call notifyListeners() here — see constructor doc above.
  }

  Future<void> setAutoPlayVideos(bool value) async {
    _autoPlayVideos = value;
    await _prefs.setBool(_kAutoPlayVideosKey, value);
    notifyListeners();
  }

  Future<void> setMuteVideosByDefault(bool value) async {
    _muteVideosByDefault = value;
    await _prefs.setBool(_kMuteVideosKey, value);
    notifyListeners();
  }

  Future<void> setUseSystemBrowser(bool value) async {
    _useSystemBrowser = value;
    await _prefs.setBool(_kUseSystemBrowserKey, value);
    notifyListeners();
  }

  Future<void> setHideReadPosts(bool value) async {
    _hideReadPosts = value;
    await _prefs.setBool(_kHideReadPostsKey, value);
    notifyListeners();
  }

  Future<void> setHideNsfw(bool value) async {
    _hideNsfw = value;
    await _prefs.setBool(_kHideNsfwKey, value);
    notifyListeners();
  }

  Future<void> setRequireBiometricForNsfw(bool value) async {
    _requireBiometricForNsfw = value;
    await _prefs.setBool(_kRequireBiometricForNsfwKey, value);
    notifyListeners();
  }

  Future<void> setDefaultSort(FeedSort sort) async {
    _defaultSort = sort;
    await _prefs.setString(_kDefaultSortKey, sort.name);
    notifyListeners();
  }
}
