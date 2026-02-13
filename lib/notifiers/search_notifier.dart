import 'package:flutter/foundation.dart';
import '../repositories/subreddit_repository.dart';
import '../models/subreddit.dart';

/// Notifier for managing subreddit search state.
class SearchNotifier extends ChangeNotifier {
  SubredditRepository? _repository;

  String _query = '';
  List<Subreddit> _results = [];
  bool _isLoading = false;

  String get query => _query;
  List<Subreddit> get results => _results;
  bool get isLoading => _isLoading;

  /// Sets the repository. Called by ProxyProvider.
  void setRepository(SubredditRepository repository) {
    _repository = repository;
  }

  /// Searches for subreddits by name.
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
    } catch (e) {
      if (_query == query) {
        _results = [];
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Clears the search state.
  void clear() {
    _query = '';
    _results = [];
    _isLoading = false;
    notifyListeners();
  }
}
