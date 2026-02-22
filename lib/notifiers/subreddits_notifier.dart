import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/repositories/subreddit_repository.dart';

/// Notifier for managing subscribed subreddits.
class SubredditsNotifier extends ChangeNotifier {
  SubredditRepository? _repository;

  List<Subreddit> _subreddits = [];

  List<Subreddit> get subreddits => _subreddits;

  /// Checks if a subreddit is currently subscribed.
  bool isSubscribed(String name) {
    return _subreddits.any(
      (s) => s.displayName.toLowerCase() == name.toLowerCase(),
    );
  }

  // ignore: use_setters_to_change_properties, method does more than set
  void setRepository(SubredditRepository repository) {
    _repository = repository;
  }

  Future<void> fetch() async {
    if (_repository == null) {
      return;
    }
    try {
      _subreddits = await _repository!.getSubscribed();
      notifyListeners();
    } on Exception catch (_) {
      // Keep current state on error
    }
  }

  /// Clears the subreddits list (e.g., on logout).
  void clear() {
    _subreddits = [];
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
