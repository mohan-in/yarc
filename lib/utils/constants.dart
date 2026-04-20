/// Application-wide constants for the YARC Reddit client.
library;

/// Scroll threshold (in pixels) before pagination triggers.
/// When the user scrolls within this distance from the bottom, new posts load.
const double kPaginationThreshold = 500;

/// Scroll distance (in pixels) between image precache operations.
/// Throttles precaching to avoid excessive network calls.
const double kPrecacheScrollThreshold = 500;

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

/// Minimum visible fraction of a video to trigger autoplay.
const double kVideoPlayThreshold = 0.4;

/// Visible fraction below which a playing video will be paused.
/// Lower than [kVideoPlayThreshold] to provide hysteresis and prevent
/// rapid play/pause cycling at the boundary.
const double kVideoPauseThreshold = 0.2;

/// Maximum fraction of viewport height a video is allowed to occupy.
/// Prevents tall portrait videos from filling the entire screen and
/// blocking scroll interaction or deadlocking the autoplay system.
const double kVideoMaxHeightFraction = 0.75;

/// Minimum visible fraction to steal playback from another playing video.
/// Higher than [kVideoPlayThreshold] to prevent two partially-visible
/// videos from rapidly swapping ownership.
const double kVideoStealThreshold = 0.6;

/// Fallback height (in pixels) for image carousels without an aspect ratio.
const double kCarouselFallbackHeight = 400;

/// Debounce duration for subreddit search input.
const Duration kSearchDebounceDuration = Duration(milliseconds: 300);

/// Duration of the animated scroll-to-top action.
const Duration kScrollToTopDuration = Duration(milliseconds: 300);
