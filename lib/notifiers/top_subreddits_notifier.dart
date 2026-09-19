import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/repositories/subreddit_repository.dart';

/// Notifier for lazily loading pages of the most popular subreddits.
///
/// Callers should invoke [loadNextPage] to fetch the first (or next) page.
/// Subsequent calls while loading, or after all pages are exhausted, are
/// silently ignored so scroll listeners can call freely without guards.
class TopSubredditsNotifier extends ChangeNotifier {
  SubredditRepository? _repository;

  List<Subreddit> _subreddits = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  String? _nextAfter;

  List<Subreddit> get subreddits => _subreddits;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  // ignore: use_setters_to_change_properties, method does more than set
  void setRepository(SubredditRepository repository) {
    _repository = repository;
  }

  /// Clears the error and resets the list for a fresh load.
  Future<void> refresh() async {
    _subreddits = [];
    _nextAfter = null;
    _hasMore = true;
    _errorMessage = null;
    await loadNextPage();
  }

  /// Loads the next page of popular subreddits.
  ///
  /// No-ops if already loading, if the repository is not wired yet,
  /// or if there are no more pages.
  Future<void> loadNextPage() async {
    if (_repository == null || _isLoading || !_hasMore) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository!.getPopular(after: _nextAfter);
      _subreddits = [..._subreddits, ...result.subreddits];
      _nextAfter = result.nextAfter;
      _hasMore = result.nextAfter != null && result.subreddits.isNotEmpty;
    } on Exception catch (e) {
      developer.log(
        'Failed to load popular subreddits: $e',
        name: 'TopSubredditsNotifier',
      );
      _errorMessage = 'Failed to load popular subreddits.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears the error message.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
