import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/service_locator.dart';
import '../models/subreddit.dart';
import '../services/reddit_service.dart';

/// Search state to hold query and results.
class SearchState {
  final String query;
  final List<Subreddit> results;
  final bool isLoading;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
  });

  SearchState copyWith({
    String? query,
    List<Subreddit>? results,
    bool? isLoading,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier for managing subreddit search state.
class SearchNotifier extends Notifier<SearchState> {
  late final RedditService _redditService;

  @override
  SearchState build() {
    _redditService = getIt<RedditService>();
    return const SearchState();
  }

  /// Updates the search query and fetches results.
  Future<void> search(String query) async {
    if (query.length < 2) {
      state = SearchState(query: query, results: [], isLoading: false);
      return;
    }

    state = state.copyWith(query: query, isLoading: true);

    try {
      final results = await _redditService.searchSubreddits(query);
      // Only update if query hasn't changed during fetch
      if (state.query == query) {
        state = state.copyWith(results: results, isLoading: false);
      }
    } catch (e) {
      if (state.query == query) {
        state = state.copyWith(results: [], isLoading: false);
      }
    }
  }

  /// Clears the search state.
  void clear() {
    state = const SearchState();
  }
}

/// Provider for SearchNotifier.
final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
