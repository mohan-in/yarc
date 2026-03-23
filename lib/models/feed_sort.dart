/// The sort order for feed posts.
enum FeedSort {
  /// Best posts (front page only, falls back to hot for subreddits).
  best,

  /// Currently trending posts.
  hot,

  /// Most recently submitted posts.
  newest,

  /// Highest scoring posts (requires a time filter).
  top,

  /// Most controversial posts (requires a time filter).
  controversial,

  /// Posts gaining traction.
  rising,
}

/// Display label for a [FeedSort] value.
String feedSortLabel(FeedSort sort) {
  return switch (sort) {
    FeedSort.best => 'Best',
    FeedSort.hot => 'Hot',
    FeedSort.newest => 'New',
    FeedSort.top => 'Top',
    FeedSort.controversial => 'Controversial',
    FeedSort.rising => 'Rising',
  };
}

/// Whether [sort] requires a companion time filter selection.
bool feedSortNeedsTimeFilter(FeedSort sort) {
  return sort == FeedSort.top || sort == FeedSort.controversial;
}
