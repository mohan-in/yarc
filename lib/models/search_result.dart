import 'package:flutter/foundation.dart';
import 'package:yarc/models/subreddit.dart';

/// Result type returned by the search delegate.
/// Contains either a selected subreddit or a selected user (not both).
@immutable
class SearchResult {
  const SearchResult({this.subreddit, this.username});

  final Subreddit? subreddit;
  final String? username;
}
