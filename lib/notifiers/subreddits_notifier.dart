import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:yarc/models/custom_feed.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/repositories/subreddit_repository.dart';

/// Notifier for managing subscribed subreddits.
class SubredditsNotifier extends ChangeNotifier {
  SubredditRepository? _repository;

  List<Subreddit> _subreddits = [];
  List<CustomFeed> _customFeeds = [];
  bool _isLoading = false;
  String? _errorMessage;

  /// Cache of lower-cased display names for O(1) subscription lookups.
  /// Nulled out whenever [_subreddits] changes.
  Set<String>? _subscribedNames;

  /// Lazily builds and returns the subscribed-names cache.
  Set<String> get _subscribed {
    return _subscribedNames ??= {
      for (final s in _subreddits) s.displayName.toLowerCase(),
    };
  }

  void _invalidateSubscribedSet() => _subscribedNames = null;

  List<Subreddit> get subreddits => _subreddits;
  List<CustomFeed> get customFeeds => _customFeeds;
  bool get isLoading => _isLoading;

  /// Non-null when the last [fetch] or [toggleSubscription] call failed.
  /// Call [clearError] to dismiss.
  String? get errorMessage => _errorMessage;

  /// Clears the current error message.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Checks if a subreddit is currently subscribed. O(1) via cached Set.
  bool isSubscribed(String name) {
    return _subscribed.contains(name.toLowerCase());
  }

  // ignore: use_setters_to_change_properties, method does more than set
  void setRepository(SubredditRepository repository) {
    _repository = repository;
  }

  Future<void> fetch() async {
    if (_repository == null) {
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository!.getSubscribed(),
        _repository!.getCustomFeeds(),
      ]);
      _subreddits = results[0] as List<Subreddit>;
      _customFeeds = results[1] as List<CustomFeed>;
      _invalidateSubscribedSet();
    } on Exception catch (e) {
      developer.log(
        'Failed to fetch subreddits/custom feeds: $e',
        name: 'SubredditsNotifier',
      );
      _errorMessage = 'Failed to load subreddits: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears the subreddits list (e.g., on logout).
  void clear() {
    _subreddits = [];
    _customFeeds = [];
    _errorMessage = null;
    _isLoading = false;
    _invalidateSubscribedSet();
    notifyListeners();
  }

  /// Toggles the subscription status of a subreddit.
  Future<void> toggleSubscription(Subreddit subreddit) async {
    if (_repository == null) {
      return;
    }
    final name = subreddit.displayName;
    final currentlySubscribed = isSubscribed(name);

    try {
      if (currentlySubscribed) {
        await _repository!.unsubscribe(name);
        // Create a new list so Selector detects the change by identity
        _subreddits = _subreddits
            .where(
              (s) => s.displayName.toLowerCase() != name.toLowerCase(),
            )
            .toList();
      } else {
        await _repository!.subscribe(name);
        _subreddits = [..._subreddits, subreddit]
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
      }
      _invalidateSubscribedSet();
      notifyListeners();
    } on Exception catch (e) {
      developer.log(
        'Error toggling subscription: $e',
        name: 'SubredditsNotifier',
      );
      rethrow;
    }
  }
}
