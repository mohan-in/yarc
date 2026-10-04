# YARC Codebase Improvement Proposals & Technical Roadmap

This roadmap details the planned improvements, architectural refinements, and quality enhancements for the **YARC (Yet Another Reddit Client)** codebase. Tasks are organized into distinct phases based on architectural priority and impact.

---

## Roadmap Phases

```
┌─────────────────────────────────────────────────────────────┐
│          Phase 1: Architecture & Rules Adherence            │
│   (Model immutability, SDK decoupling, layer boundary fixes) │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│       Phase 2: Security, Storage & Resource Hygiene          │
│   (Secure token storage, Hive LRU, lazy video init)         │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│             Phase 3: Test Coverage Expansion                │
│   (Parsers, services retry logic, screen widget tests)      │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│           Phase 4: Feature Polish & UX Enhancements         │
│   (Voting, collapsible comment threads, i18n catalogs)      │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Architecture & Rules Adherence

### 1. Model Immutability & Contract Conformance
- [x] **FlairItem** (`lib/models/post.dart`): Implement `operator ==`, `hashCode`, and `copyWith`.
- [x] **Comment** (`lib/models/comment.dart`): Add `copyWith`.
- [x] **CustomFeed** (`lib/models/custom_feed.dart`): Add `copyWith`.
- [x] **RedditorInfo** (`lib/models/redditor_info.dart`): Add `copyWith`.
- [x] **Subreddit** (`lib/models/subreddit.dart`): Add `copyWith`.

### 2. External SDK Decoupling
- [x] Extract DRAW SDK mapping logic out of domain models:
  - Create `CommentParser` in `lib/utils/parsers/` and remove `import 'package:draw/draw.dart'` from `lib/models/comment.dart`.
  - Create `SubredditParser` in `lib/utils/parsers/` and remove `import 'package:draw/draw.dart'` from `lib/models/subreddit.dart`.
  - Create `CustomFeedParser` in `lib/utils/parsers/` and remove `import 'package:draw/draw.dart'` from `lib/models/custom_feed.dart`.

### 3. Layer Boundary Fixes & Navigator Centralization
- [x] **Fix Service Leak in `main.dart`**:
  - Add `Future<Post?> getPost(String id)` to `PostRepository`.
  - Refactor `_handleDeepLink` in `lib/main.dart` to use `PostRepository` instead of calling `context.read<RedditService>().fetchPost(...)`.
- [x] **Centralize Router Access**:
  - Add `AppRouter.toSavedPosts(BuildContext context, String username)`.
  - Add `AppRouter.toFullScreenImageView(BuildContext context, ...)`.
  - Eliminate all remaining inline `Navigator.push(MaterialPageRoute(...))` calls across screens and widgets.
- [x] **Decompose `FeedNotifier`**:
  - Extract a dedicated `PostDetailNotifier` or `CommentsNotifier` for loading, refreshing, and managing comments in `PostDetailContent`, freeing `FeedNotifier` from non-feed responsibilities.
  - Relocate `fetchUser` from `SubredditRepository` to a domain-appropriate repository (`UserRepository` or `AccountRepository`).

---

## Phase 2: Security, Storage & Resource Hygiene

### 1. Secure Credential Storage
- [x] Migrate OAuth access and refresh tokens from plaintext `SharedPreferences` in `AuthService` to hardware-backed secure storage using `flutter_secure_storage` (Android Keystore / EncryptedSharedPreferences and iOS Keychain).
- [x] Preserve `SharedPreferences` strictly for non-sensitive UI settings (theme, sort preference, mute default).

### 2. History & Local Storage Hygiene
- [x] Refactor `HistoryService` to remove the static `late final Box<bool> _box` in favor of constructor dependency injection (`HistoryService(this._box)`).
- [x] Implement an LRU eviction or rolling cap (e.g. limit to most recent 2,000 read post IDs with timestamps) to prevent unbounded memory growth on cold start.

### 3. Video & Media Resource Optimization
- [x] Refactor `RedditVideoPlayer` to avoid allocating `VideoPlayerController.networkUrl(...)` unconditionally on widget creation.
  - When `autoPlay` is disabled, display a static preview thumbnail with a play icon and allocate the video controller on user interaction.
  - When `autoPlay` is enabled, defer controller allocation until the player enters the middle safe zone.
- [x] Replace bare `on Object catch (_) {}` in `video_player.dart` and `auth_service.dart` with typed exception catches and `developer.log` output.

---

## Phase 3: Test Coverage Expansion

### 1. Parsers & Utility Unit Tests
- [x] Unit tests for `PostParser` and `lib/utils/parsers/`:
  - `MediaExtractor`: Video URL resolution, preview image extraction, YouTube ID parsing.
  - `GalleryParser`: Multi-image metadata and aspect ratio calculation.
  - `CrosspostParser`: Parent post resolution and media fallbacks.
  - `FlairParser`: Custom emoji and richtext decoding.
  - `ContentSanitizer`: Selftext image URL stripping and markdown cleansing.

### 2. Services & Repositories Unit Tests
- [x] Unit tests for `AuthService` (token refresh triggers, revoked token detection, CSRF state verification).
- [x] Unit tests for `RedditService` (auth retry mechanism on 401/403, error mapping).
- [x] Unit tests for `PostRepository`, `SubredditRepository`, and `HistoryService`.

### 3. Screen Widget & State Tests
- [x] Widget tests for `HomeScreen` (narrow layout, two-pane master-detail wide layout, drawer navigation).
- [x] Widget tests for `PostDetailScreen` and `PostDetailContent` (comment list states, error handling).
- [x] Unit tests for `SearchNotifier`, `SubredditsNotifier`, and `VideoAutoplayNotifier`.

---

## Phase 4: Feature Polish & UX Enhancements

### 1. Interactive Reddit Actions
- [x] **Voting**: Implement upvote / downvote actions on `PostCard` and `CommentTile` leveraging the `'vote'` OAuth scope already requested in `AuthService`.
- [x] **Comment Collapsing**: Allow tapping comment headers to collapse and expand nested reply threads with smooth height transitions.

### 2. Offline Reading Experience
- [x] Cache recent posts in local storage so users opening the app without internet connectivity can view previously fetched posts.

### 3. Internationalization (i18n)
- [x] Extract hardcoded English strings into `.arb` translation catalogs using Flutter's official localization system (`flutter_localizations`).
- [x] Add semantic accessibility labels to custom icon buttons and media badges.
