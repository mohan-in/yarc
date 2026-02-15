# YARC Architecture

## Overview

YARC (Yet Another Reddit Client) uses a clean layered architecture with Provider for dependency injection and ChangeNotifier for state management.

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                            │
│              screens/ + widgets/                            │
└────────────────────────┬────────────────────────────────────┘
                         │ context.watch/read
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
├── main.dart              # App entry + DI setup
├── models/                # Data classes
│   ├── post.dart
│   ├── comment.dart
│   ├── subreddit.dart
│   └── models.dart            # Barrel file
├── services/              # Raw data access
│   ├── auth_service.dart      # OAuth authentication
│   ├── reddit_service.dart    # Reddit API calls
│   ├── history_service.dart   # Local history tracking (Hive)
│   └── deep_link_service.dart # Deep linking logic
├── repositories/          # Business logic
│   ├── auth_repository.dart
│   ├── post_repository.dart
│   └── subreddit_repository.dart
├── notifiers/             # State management
│   ├── auth_notifier.dart
│   ├── feed_notifier.dart
│   ├── search_notifier.dart
│   └── subreddits_notifier.dart
├── screens/               # Full-page UI
│   ├── home_screen.dart
│   └── post_detail_screen.dart
├── widgets/               # Reusable UI components
├── utils/                 # Helper functions
└── theme/                 # App theming
```

---

## Layer Responsibilities

### Services
Raw data access—no business logic.

| Service | Responsibility |
|---------|---------------|
| `AuthService` | OAuth2 flow, token storage |
| `RedditService` | Reddit API calls via `draw` package |
| `HistoryService` | Hive-based read history tracking |
| `DeepLinkService` | Handles incoming deep links (cold/warm start) |

### Repositories
Orchestrate services, apply business rules.

| Repository | Dependencies | Purpose |
|------------|--------------|---------|
| `AuthRepository` | AuthService | Login/logout abstraction |
| `PostRepository` | RedditService, HistoryService | Posts & history tracking |
| `SubredditRepository` | RedditService | Subreddits + search |

### Notifiers
Hold reactive state, notify UI of changes.

| Notifier | State | Key Actions |
|----------|-------|-------------|
| `AuthNotifier` | `isLoggedIn`, `isInitialized` | `login()`, `logout()` |
| `FeedNotifier` | `posts`, `currentSubreddit`, `hideRead` | `loadPosts()`, `selectSubreddit()` |
| `SubredditsNotifier` | `subreddits` | `fetch()` |
| `SearchNotifier` | `query`, `results` | `search()` |



---

## Key Concepts & Patterns

### Barrel Files
Files like `models/models.dart`, `widgets/widgets.dart`, and `utils/utils.dart` are "barrel files". They export all files in their directory to simplify imports elsewhere.
- **Convention**: Keep them clean, containing *only* export statements.

### Local Storage (Hive)
- **Service**: `HistoryService` manages the Hive boxes for tracking read posts.
- **Usage**: Simple key-value storage for post IDs marked as read.

### Deep Linking
- **Service**: `DeepLinkService` uses `app_links` to handle universal links and custom schemes.
- **Logic**: Parses URLs (e.g., `/r/flutter`) into `DeepLinkResult` objects which `main.dart` uses to navigate.

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
    
    // Notifiers
    ChangeNotifierProxyProvider<AuthRepository, AuthNotifier>(...),
    ...
  ],
)
```

---

## Data Flow Example

**User taps a subreddit in drawer:**

```
1. UI: context.read<FeedNotifier>().selectSubreddit("flutter")
         ↓
2. FeedNotifier.selectSubreddit():
   - Sets currentSubreddit = "flutter"
   - Calls loadPosts()
         ↓
3. PostRepository.getPosts(subreddit: "flutter"):
   - Calls RedditService.fetchPosts()
         ↓
4. RedditService.fetchPosts():
   - Calls Reddit API via `draw` package
         ↓
5. FeedNotifier receives posts:
   - Updates _posts list
   - Calls notifyListeners()
         ↓
6. UI rebuilds via context.watch<FeedNotifier>()
```

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `provider` | Dependency injection + state management |
| `draw` | Reddit API client |
| `hive_flutter` | Local storage |
| `cached_network_image` | Image caching |
| `flutter_web_auth_2` | OAuth2 authentication |
