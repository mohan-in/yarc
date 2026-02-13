import 'package:flutter/foundation.dart';
import '../repositories/subreddit_repository.dart';
import '../models/subreddit.dart';

/// Notifier for managing subscribed subreddits.
class SubredditsNotifier extends ChangeNotifier {
  SubredditRepository? _repository;

  List<Subreddit> _subreddits = [];

  List<Subreddit> get subreddits => _subreddits;

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
    } catch (e) {
      // Keep current state on error
    }
  }

  /// Clears the subreddits list (e.g., on logout).
  void clear() {
    _subreddits = [];
    notifyListeners();
  }
}
