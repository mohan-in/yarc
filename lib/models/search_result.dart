import 'package:flutter/foundation.dart';
import 'package:yarc/models/subreddit.dart';

/// Result type returned by the search delegate.
/// Contains a selected subreddit, a selected user, or a scoped post search.
@immutable
class SearchResult {
  const SearchResult({
    this.subreddit,
    this.username,
    this.postSearchQuery,
    this.targetSubreddit,
  });

  final Subreddit? subreddit;
  final String? username;
  final String? postSearchQuery;
  final String? targetSubreddit;

  SearchResult copyWith({
    Subreddit? subreddit,
    String? username,
    String? postSearchQuery,
    String? targetSubreddit,
  }) {
    return SearchResult(
      subreddit: subreddit ?? this.subreddit,
      username: username ?? this.username,
      postSearchQuery: postSearchQuery ?? this.postSearchQuery,
      targetSubreddit: targetSubreddit ?? this.targetSubreddit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          subreddit == other.subreddit &&
          username == other.username &&
          postSearchQuery == other.postSearchQuery &&
          targetSubreddit == other.targetSubreddit;

  @override
  int get hashCode => Object.hash(
    subreddit,
    username,
    postSearchQuery,
    targetSubreddit,
  );
}
