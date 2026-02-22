/// Application-wide constants for the YARC Reddit client.
library;

/// Scroll threshold (in pixels) before pagination triggers.
/// When user scrolls within this distance from the bottom, new posts load.
const int kPaginationThreshold = 800;

/// Scroll distance (in pixels) between image precache operations.
/// Throttles precaching to avoid excessive network calls.
const double kPrecacheScrollThreshold = 600;

/// Default number of posts to fetch per API request.
const int kDefaultPostLimit = 10;

/// Estimated height of a post card in pixels.
/// Used for calculating visible post indices during precaching.
const double kEstimatedPostCardHeight = 300;

/// Number of posts to prefetch ahead of the visible area.
const int kPrefetchPostCount = 5;

/// Number of visible posts before prefetch starts.
const int kVisiblePostsBeforePrefetch = 3;

/// Maximum subreddits to fetch for subscriptions list.
const int kMaxSubscribedSubreddits = 100;

/// Reddit API user-agent string.
/// Reddit requires a descriptive user-agent for API compliance.
const String kUserAgent = 'flutter_reddit_demo/1.0.0 (by /u/antigravity)';

/// Top fraction of the viewport for the video autoplay safe zone.
const double kVideoSafeZoneTop = 0.15;

/// Bottom fraction of the viewport for the video autoplay safe zone.
const double kVideoSafeZoneBottom = 0.85;

/// Fallback height (in pixels) for image carousels without an aspect ratio.
const double kCarouselFallbackHeight = 400;

/// Debounce duration for subreddit search input.
const Duration kSearchDebounceDuration = Duration(milliseconds: 300);
