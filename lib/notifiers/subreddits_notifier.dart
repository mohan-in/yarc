import 'package:flutter/foundation.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/repositories/subreddit_repository.dart';

/// Notifier for managing subscribed subreddits.
class SubredditsNotifier extends ChangeNotifier {
  SubredditRepository? _repository;

  List<Subreddit> _subreddits = [];

  List<Subreddit> get subreddits => _subreddits;

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
}
