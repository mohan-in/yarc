// Positional boolean parameters are clear here given the setter naming.
// ignore_for_file: avoid_positional_boolean_parameters


import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yarc/models/feed_sort.dart';

class SettingsNotifier extends ChangeNotifier {
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

  bool _autoPlayVideos = true;
  bool _muteVideosByDefault = true;
  bool _useSystemBrowser = false;
  bool _hideReadPosts = false;
  bool _hideNsfw = true;
  FeedSort _defaultSort = FeedSort.best;

  bool get autoPlayVideos => _autoPlayVideos;
  bool get muteVideosByDefault => _muteVideosByDefault;
  bool get useSystemBrowser => _useSystemBrowser;
  bool get hideReadPosts => _hideReadPosts;
  bool get hideNsfw => _hideNsfw;
  FeedSort get defaultSort => _defaultSort;

  void _loadSettings() {
    _autoPlayVideos = _prefs.getBool(_kAutoPlayVideosKey) ?? true;
    _muteVideosByDefault = _prefs.getBool(_kMuteVideosKey) ?? true;
    _useSystemBrowser = _prefs.getBool(_kUseSystemBrowserKey) ?? false;
    _hideReadPosts = _prefs.getBool(_kHideReadPostsKey) ?? false;
    _hideNsfw = _prefs.getBool(_kHideNsfwKey) ?? true;

    final sortString = _prefs.getString(_kDefaultSortKey);
    if (sortString != null) {
      _defaultSort = FeedSort.values.firstWhere(
        (s) => s.name == sortString,
        orElse: () => FeedSort.best,
      );
    }
    notifyListeners();
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

  Future<void> setDefaultSort(FeedSort sort) async {
    _defaultSort = sort;
    await _prefs.setString(_kDefaultSortKey, sort.name);
    notifyListeners();
  }
}
