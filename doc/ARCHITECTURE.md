# YARC Architecture

## Overview

YARC (Yet Another Reddit Client) uses a clean layered architecture with Provider for dependency injection and ChangeNotifier for state management.

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                            │
│              screens/ + widgets/                            │
└────────────────────────┬────────────────────────────────────┘
                         │ context.watch/read/select
┌────────────────────────▼────────────────────────────────────┐
│                    State Layer                              │
│                     notifiers/                              │
│           (ChangeNotifier pattern)                          │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                  Repository Layer                           │
│                   repositories/                             │
│         (Business logic + data orchestration)               │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                   Service Layer                             │
│                     services/                               │
│           (API calls + local storage)                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
lib/
├── main.dart                # App entry + DI setup + deep linking
├── models/                  # Data classes & type aliases
│   ├── comment.dart
│   ├── post.dart
│   ├── subreddit.dart
│   ├── types.dart               # PostsResult typedef
│   └── models.dart              # Barrel file
├── services/                # Raw data access
│   ├── auth_service.dart        # OAuth2 authentication + AuthState stream
│   ├── reddit_service.dart      # Reddit API calls
│   ├── history_service.dart     # Local history tracking (Hive)
│   ├── deep_link_service.dart   # Deep linking logic
│   └── services.dart            # Barrel file
├── repositories/            # Business logic
│   ├── auth_repository.dart
│   ├── post_repository.dart
│   ├── subreddit_repository.dart
│   └── repositories.dart        # Barrel file
├── notifiers/               # State management
│   ├── auth_notifier.dart
│   ├── feed_notifier.dart
│   ├── search_notifier.dart
│   ├── subreddits_notifier.dart
│   ├── video_autoplay_notifier.dart
│   └── notifiers.dart           # Barrel file
├── screens/                 # Full-page UI
│   ├── home_screen.dart
│   └── post_detail_screen.dart
├── widgets/                 # Reusable UI components
│   ├── app_drawer.dart          # Navigation drawer
│   ├── cached_image.dart        # Cached network image wrapper
│   ├── comment_list.dart        # Comment thread list
│   ├── comment_tile.dart        # Single comment w/ nested replies
│   ├── faded_truncation.dart    # Truncated text with fade effect
│   ├── full_screen_image_view.dart
│   ├── image_carousel.dart      # Swiping image gallery
│   ├── login_prompt.dart        # OAuth login CTA
│   ├── markdown_content.dart    # Markdown rendering
│   ├── post_card.dart           # Feed post card
│   ├── post_list.dart           # Paginated post list
│   ├── post_metadata.dart       # Author, time, score row
│   ├── subreddit_info_card.dart # Subreddit details panel
│   ├── subreddit_search_delegate.dart
│   ├── video_player.dart        # Chewie video player
│   ├── youtube_embed.dart       # YouTube embed player
│   └── widgets.dart             # Barrel file
├── utils/                   # Helper functions
│   ├── constants.dart           # App-wide constants
│   ├── date_utils.dart          # Relative date formatting
│   ├── feed_utils.dart          # Feed filtering helpers
│   ├── html_utils.dart          # HTML entity decoding
│   ├── image_utils.dart         # Image URL resolution
│   ├── post_parser.dart         # Reddit post content parser
│   └── utils.dart               # Barrel file
└── theme/                   # App theming
    └── theme.dart               # Material 3 ThemeData
```

---

## Layer Responsibilities

### Services
Raw data access—no business logic.

| Service | Responsibility |
|---------|---------------|
| `AuthService` | OAuth2 flow, token storage/refresh, `AuthState` stream for session events |
| `RedditService` | Reddit API calls via `draw` package |
| `HistoryService` | Hive-based read history tracking |
| `DeepLinkService` | Handles incoming deep links (cold/warm start) via `app_links` |

### Repositories
Orchestrate services, apply business rules.

| Repository | Dependencies | Purpose |
|------------|--------------|---------|
| `AuthRepository` | AuthService | Login/logout abstraction, exposes `authStateStream` |
| `PostRepository` | RedditService, HistoryService | Post fetching, pagination, read history tracking |
| `SubredditRepository` | RedditService | Subscribed subreddits, search, subscribe/unsubscribe |

### Notifiers
Hold reactive state, notify UI of changes.

| Notifier | State | Key Actions |
|----------|-------|-------------|
| `AuthNotifier` | `isLoggedIn`, `isInitialized` | `login()`, `logout()`, listens to `AuthState` stream |
| `FeedNotifier` | `posts`, `visiblePosts`, `currentSubreddit`, `hideRead`, `readPostIds` | `loadPosts()`, `refresh()`, `selectSubreddit()`, `selectSubredditWithInfo()`, `toggleHideRead()`, `markAsRead()`, `handleScroll()` |
| `SubredditsNotifier` | `subreddits` | `fetch()`, `clear()`, `toggleSubscription()`, `isSubscribed()` |
| `SearchNotifier` | `query`, `results`, `isLoading` | `search()`, `clear()` |
| `VideoAutoplayNotifier` | `playingVideoId` | `play()`, `stop()`, `notifyScroll()` — coordinates single-video-at-a-time autoplay |

---

## Key Concepts & Patterns

### Barrel Files
Every layer uses a barrel file (`models.dart`, `services.dart`, `repositories.dart`, `notifiers.dart`, `widgets.dart`, `utils.dart`) that re-exports all files in its directory to simplify imports.
- **Convention**: Keep them clean, containing *only* export statements.

### Type Aliases
`models/types.dart` contains record typedefs (e.g. `PostsResult`) used across layers to avoid ad-hoc tuples.

### Auth State Stream
`AuthService` emits `AuthState` events (`loggedIn`, `loggedOut`, `unauthenticated`) via a broadcast stream. `AuthNotifier` subscribes to this stream via `AuthRepository.authStateStream` for reactive auth state (token revocation triggers global logout without manual polling).

### Local Storage (Hive)
- **Service**: `HistoryService` manages Hive boxes for tracking read posts.
- **Usage**: Simple key-value storage for post IDs marked as read.
- **Init**: `HistoryService.init()` is called in `main()` before `runApp`.

### Deep Linking
- **Service**: `DeepLinkService` uses `app_links` to handle universal links and custom schemes.
- **Logic**: Parses URLs (e.g., `/r/flutter`, `/r/flutter/comments/xyz`) into `DeepLinkResult` objects.
- **Handling**: `_YarcAppState` manages both cold-start (pending link) and warm-start (stream listener) deep links.

### Samsung DeX Compatibility
- **Plugin**: `dex_compat` (local path dependency) detects desktop mode on Samsung DeX.
- **Usage**: `DexCompat.isDesktopMode()` in `main()`, `DexCompat.builder()` in `MaterialApp.builder` for adaptive window handling.

### Video Autoplay
- `VideoAutoplayNotifier` enforces single-video-at-a-time playback across the feed.
- Feed scroll events trigger `notifyScroll()`, and individual `VideoPlayer` widgets check their visibility to auto-play/stop.

---

## Dependency Injection

Configured in `main.dart` using `MultiProvider`:

```dart
MultiProvider(
  providers: [
    // Services (no dependencies)
    Provider(create: (_) => AuthService()),
    Provider(create: (_) => HistoryService()),

    // Services (with dependencies)
    ProxyProvider<AuthService, RedditService>(...),

    // Repositories
    ProxyProvider<AuthService, AuthRepository>(...),
    ProxyProvider2<RedditService, HistoryService, PostRepository>(...),
    ProxyProvider<RedditService, SubredditRepository>(...),

    // Notifiers (with repository dependencies)
    ChangeNotifierProxyProvider<AuthRepository, AuthNotifier>(...),
    ChangeNotifierProxyProvider<PostRepository, FeedNotifier>(...),
    ChangeNotifierProxyProvider<SubredditRepository, SubredditsNotifier>(...),
    ChangeNotifierProxyProvider<SubredditRepository, SearchNotifier>(...),

    // Standalone notifiers
    ChangeNotifierProvider(create: (_) => VideoAutoplayNotifier()),
  ],
)
```

---

## Data Flow Example

**User taps a subreddit in the drawer:**

```
1. UI: context.read<FeedNotifier>().selectSubreddit("flutter")
         ↓
2. FeedNotifier.selectSubreddit():
   - Clears posts, resets pagination cursor
   - Sets currentSubreddit = "flutter"
   - Calls loadPosts()
         ↓
3. PostRepository.getPosts(subreddit: "flutter"):
   - Calls RedditService.fetchPosts()
   - Returns PostsResult (posts + nextAfter cursor)
         ↓
4. RedditService.fetchPosts():
   - Calls Reddit API via `draw` package
         ↓
5. FeedNotifier receives PostsResult:
   - Deduplicates and updates _posts list
   - Invalidates cached visiblePosts
   - Calls notifyListeners()
         ↓
6. UI rebuilds via context.select<FeedNotifier, ...>(...)
```

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `provider` | Dependency injection + state management |
| `draw` | Reddit API client |
| `hive_flutter` | Local storage |
| `shared_preferences` | Credential persistence |
| `cached_network_image` | Image caching |
| `flutter_web_auth_2` | OAuth2 authentication |
| `app_links` | Deep linking |
| `dex_compat` | Samsung DeX desktop-mode detection (local plugin) |
| `chewie` / `video_player` | Video playback |
| `youtube_player_flutter` | YouTube embed playback |
| `flutter_markdown_plus` / `markdown` | Markdown rendering |
| `url_launcher` | Opening external links |
| `visibility_detector` | Scroll-based visibility tracking (autoplay) |
| `intl` | Date/number formatting |
| `html_unescape` | HTML entity decoding |
