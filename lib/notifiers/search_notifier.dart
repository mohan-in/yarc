import 'package:flutter/foundation.dart';
import 'package:yarc/models/redditor_info.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/repositories/subreddit_repository.dart';
import 'package:yarc/services/reddit_service.dart';

/// Notifier for managing search state (subreddits and users).
class SearchNotifier extends ChangeNotifier {
  SubredditRepository? _repository;
  RedditService? _redditService;

  // Subreddit search state
  String _query = '';
  List<Subreddit> _results = [];
  bool _isLoading = false;

  // User search state
  String _userQuery = '';
  RedditorInfo? _userResult;
  bool _isUserLoading = false;
  bool _userSearched = false;

  String get query => _query;
  List<Subreddit> get results => _results;
  bool get isLoading => _isLoading;

  RedditorInfo? get userResult => _userResult;
  bool get isUserLoading => _isUserLoading;

  /// Whether a user search has been performed (to distinguish "not searched"
  /// from "searched but not found").
  bool get userSearched => _userSearched;

  /// Sets the subreddit repository. Called by ProxyProvider.
  // ignore: use_setters_to_change_properties
  void setRepository(SubredditRepository repository) {
    _repository = repository;
  }

  /// Sets the Reddit service for user lookups.
  // ignore: use_setters_to_change_properties
  void setRedditService(RedditService service) {
    _redditService = service;
  }

  Future<void> search(String query) async {
    if (_repository == null) {
      return;
    }

    _query = query;

    if (query.length < 2) {
      _results = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final results = await _repository!.search(query);
      if (_query == query) {
        _results = results;
        _isLoading = false;
        notifyListeners();
      }
    } on Exception catch (_) {
      if (_query == query) {
        _results = [];
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Searches for a user by exact username.
  Future<void> searchUser(String username) async {
    if (_redditService == null) {
      return;
    }

    _userQuery = username;

    if (username.length < 2) {
      _userResult = null;
      _isUserLoading = false;
      _userSearched = false;
      notifyListeners();
      return;
    }

    _isUserLoading = true;
    _userSearched = false;
    notifyListeners();

    try {
      final result = await _redditService!.fetchUser(username);
      if (_userQuery == username) {
        _userResult = result;
        _isUserLoading = false;
        _userSearched = true;
        notifyListeners();
      }
    } on Exception catch (_) {
      if (_userQuery == username) {
        _userResult = null;
        _isUserLoading = false;
        _userSearched = true;
        notifyListeners();
      }
    }
  }

  void clear() {
    _query = '';
    _results = [];
    _isLoading = false;
    _userQuery = '';
    _userResult = null;
    _isUserLoading = false;
    _userSearched = false;
    notifyListeners();
  }
}
