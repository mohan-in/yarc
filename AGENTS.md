# AGENTS.md — YARC Coding Conventions & Agent Guidance

This file describes the project architecture, toolchain, and coding conventions
for **YARC (Yet Another Reddit Client)** — a Flutter Reddit client targeting
Android, with experimental DeX / desktop support. AI agents and contributors
should read this before making any changes.

---

## 1. Project Overview

| Item | Value |
|---|---|
| Framework | Flutter (Material 3) |
| Language | Dart ≥ 3.10.4 |
| Platform | Android (primary); DeX desktop via `dex_compat` local package |
| Reddit API | [`draw`](https://pub.dev/packages/draw) library |
| State management | `provider` — `ChangeNotifier` + `ChangeNotifierProxyProvider` |
| Local storage | `hive` (read history), `shared_preferences` (settings, auth tokens) |
| Linter preset | `very_good_analysis` v10 |
| Build-time config | `--dart-define=REDDIT_CLIENT_ID=<id>` (required to run) |

---

## 2. Repository Layout

```
lib/
├── main.dart                 # Bootstrap, DI wiring, deep-link handling
├── models/                   # Immutable data classes (@immutable)
│   ├── post.dart             # Post (value equality via props + operator==)
│   ├── comment.dart          # Comment (id-based equality)
│   ├── subreddit.dart        # Subreddit (displayName-based equality)
│   ├── custom_feed.dart
│   ├── feed_sort.dart        # Enum for sort order
│   ├── redditor_info.dart
│   ├── search_result.dart
│   ├── types.dart            # Typedef: PostsResult = ({List<Post>, String?})
│   └── models.dart           # Barrel export
├── services/                 # Thin wrappers around third-party libraries
│   ├── auth_service.dart     # OAuth2 flow, token persistence
│   ├── reddit_service.dart   # DRAW API calls, _withAuthRetry wrapper
│   ├── history_service.dart  # Hive-backed read-post tracking
│   ├── deep_link_service.dart
│   └── services.dart         # Barrel export
├── repositories/             # Compose services; owned by notifiers
│   ├── auth_repository.dart
│   ├── post_repository.dart
│   ├── subreddit_repository.dart
│   └── repositories.dart     # Barrel export
├── notifiers/                # ChangeNotifier UI state; own repositories
│   ├── auth_notifier.dart
│   ├── feed_notifier.dart
│   ├── settings_notifier.dart
│   ├── subreddits_notifier.dart
│   ├── search_notifier.dart
│   ├── theme_notifier.dart
│   ├── video_autoplay_notifier.dart
│   └── notifiers.dart        # Barrel export
├── screens/                  # Top-level routes
│   ├── home_screen.dart      # Master-detail layout (LayoutBuilder breakpoint)
│   ├── post_detail_screen.dart
│   ├── saved_posts_screen.dart
│   ├── settings_screen.dart
│   └── user_profile_screen.dart
├── widgets/                  # Reusable UI components
│   ├── post_card.dart        # Renders one post in the feed
│   ├── video_player.dart     # VisibilityDetector-based autoplay
│   ├── feed_sliver.dart      # Self-contained sliver (reads FeedNotifier)
│   ├── paginated_scroll_body.dart
│   └── …24 widgets total
├── theme/
│   └── theme.dart            # appTheme / darkAppTheme (Material 3)
│                             # CommentTheme & MediaViewerTheme extensions
└── utils/
    ├── constants.dart        # All k-prefixed app-wide constants
    ├── post_parser.dart      # Converts draw.Submission → Post
    ├── date_utils.dart       # DateUtilsHelper.formatTimeAgo(DateTime)
    ├── html_utils.dart
    ├── app_router.dart
    └── parsers/              # Sub-parsers (media, gallery, flair, crosspost)

test/
├── notifiers/
│   └── feed_notifier_test.dart
├── widgets/
│   ├── post_card_test.dart
│   └── comment_tile_test.dart
└── widget_test.dart          # Smoke test (skipped in CI)
```

---

## 3. Toolchain Commands

Always run these from the **project root** (`/home/mohan/Flutter/Projects/yarc`).

| Purpose | Command |
|---|---|
| Static analysis (must be zero issues) | `flutter analyze` |
| Auto-format (run before committing) | `dart format lib/ test/` |
| Run tests | `flutter test` |
| Run app (debug) | `flutter run --dart-define=REDDIT_CLIENT_ID=<id>` |
| Build (release) | `flutter build apk --dart-define=REDDIT_CLIENT_ID=<id>` |
| Check format without changing | `dart format lib/ test/ --output=none` |

> **Never commit with analysis errors.** Warnings are also treated as errors
> by `very_good_analysis`. Run `flutter analyze` after every change.

---

## 4. Architecture — Layered MVVM

```
UI (Screens / Widgets)
        ↕  context.read / context.select / context.watch
Notifiers (ChangeNotifier)
        ↕  method calls
Repositories (plain Dart classes)
        ↕  method calls
Services (plain Dart classes — no BuildContext)
        ↕
External (DRAW API / Hive / SharedPreferences)
```

### Rules per layer

| Layer | Rule |
|---|---|
| **Services** | Must never import `flutter` or hold `BuildContext`. Testable in pure Dart. |
| **Repositories** | Own a service reference; passed into notifiers via `setRepository()`. |
| **Notifiers** | Own a repository reference; expose read-only getters + async methods. Never call `notifyListeners()` from a constructor body. |
| **Widgets** | Use `context.select` for fine-grained subscriptions. Use `context.read` for one-shot actions. Never use `context.watch` on a large notifier. |

### Dependency Injection (`main.dart`)

All DI is wired in `_YarcAppState.build()` via `MultiProvider`. Key patterns:

```dart
// Singleton services — use prev ?? to avoid recreating on ProxyProvider rebuilds
ProxyProvider<AuthService, RedditService>(
  update: (_, auth, prev) => prev ?? RedditService(auth),
),

// Notifiers receive their repo via cascade setter, not constructor
ChangeNotifierProxyProvider<SubredditRepository, SubredditsNotifier>(
  create: (_) => SubredditsNotifier(),
  update: (_, repo, notifier) => notifier!..setRepository(repo),
),
```

> **Do not change the `prev ?? Foo(dep)` pattern** without reading the comment
> block above it in `main.dart`. These services are intentional singletons.

---

## 5. Coding Conventions

### 5.1 Dart Language

- **Dart record typedefs** for result types:
  ```dart
  typedef PostsResult = ({List<Post> posts, String? nextAfter});
  ```

- **Named parameters** are required for constructors with ≥ 2 fields. Use
  `required` for non-nullable, optional for nullable with a default.

- **`unawaited()`** from `dart:async` must wrap every fire-and-forget future
  (the linter enforces `unawaited_futures`):
  ```dart
  unawaited(feedNotifier.loadPosts());
  unawaited(_linkSubscription?.cancel());
  ```

- **`on Exception catch (e)`** — never use a bare `catch` or `on Object`.
  Catch the narrowest type. Re-throw with `rethrow` when the caller needs to
  handle it.

- **`dart:developer` log** — use `developer.log(msg, name: 'ClassName')` for
  debug logging. `print` is banned by the linter (`avoid_print`).

- **Constants** live in `lib/utils/constants.dart` and use the `k` prefix:
  `kDefaultPostLimit`, `kVideoPlayThreshold`, etc.

- **Build-time config** — the Reddit client ID is injected via
  `--dart-define=REDDIT_CLIENT_ID=…` and read with:
  ```dart
  static const String _clientId = String.fromEnvironment('REDDIT_CLIENT_ID');
  ```

### 5.2 Models

- All models are **`@immutable`** value objects.
- **Equality**: `Post` uses a full `props`-list-based `operator==` and
  `Object.hashAll(props)`. `Comment` and `Subreddit` use single-field
  id/displayName equality.
- **`copyWith`** must be provided on every model that can be partially updated
  (e.g. `Post.copyWith(isSaved: true)`).
- **Factory constructors** (`fromDraw(...)`) handle all conversion from DRAW
  library types. Domain models never reference DRAW types directly.
- **`createdUtc` is `DateTime` (UTC)** — conversion from raw API unix timestamps
  happens at the parse boundary (`PostParser`, `CrosspostParser`,
  `Comment.fromDraw`). Never store or pass raw epoch `double`/`int` values.

### 5.3 Notifiers

- Notifiers start with no repository (`_repository == null`) and receive it via
  `setRepository(repo)`, called by `ChangeNotifierProxyProvider.update`.
- **Guard every public method**: `if (_repository == null) return;`
- **State pattern**: every async operation sets `_isLoading = true` and
  notifies, then clears in a `finally` block. Errors are surfaced via
  `_errorMessage` (nullable `String`), not thrown.
- **`_resetFeed()` pattern** in `FeedNotifier`: all `select*` methods call this
  private helper to clear shared state before setting mode-specific fields.
- **Never** call `notifyListeners()` in a constructor body.
- **`dispose()`**: cancel all stream subscriptions, close all
  `StreamController`s. Example:
  ```dart
  @override
  void dispose() {
    unawaited(_saveSub?.cancel());
    unawaited(_saveEvents.close());
    super.dispose();
  }
  ```

### 5.4 Services

- `RedditService` wraps every API call in `_withAuthRetry(actionName, action)`,
  which catches 401/403, refreshes the session once, and retries. All new API
  methods must use this wrapper.
- `AuthService` uses an injected `SharedPreferences` — do not call
  `SharedPreferences.getInstance()` inside the service.
- OAuth state is validated: `authenticate()` generates a 128-bit
  `Random.secure()` state token, stores it in `_pendingOAuthState`, and
  validates the callback `?state=` before accepting the auth code.

### 5.5 Widgets

- **`context.select`** for targeted subscriptions — only rebuilds when the
  selected value changes:
  ```dart
  final isLoading = context.select<FeedNotifier, bool>((n) => n.isLoading);
  ```
- **`context.read`** for one-shot imperative calls (inside callbacks):
  ```dart
  onPressed: () => unawaited(context.read<FeedNotifier>().refresh()),
  ```
- **`mounted` check** after every `await` in `State` methods:
  ```dart
  if (!mounted) return;
  ```
- **Trailing commas** on every argument list and parameter list — enforced by
  `require_trailing_commas`.
- Widget classes are **private** (`_MyWidget`) when only used within their own
  file. Exported widgets live in `lib/widgets/` and are listed in
  `widgets/widgets.dart`.

### 5.6 Video Player

- `VideoAutoplayNotifier` coordinates single-playback by tracking `playingVideoId`.
- Each `_RedditVideoPlayerState` generates its own unique `_playerId`:
  ```dart
  _playerId = '${identityHashCode(this)}_${widget.videoUrl.hashCode}';
  ```
  Do not use `widget.videoUrl` alone — crossposts share URLs and would collide.
- Autoplay thresholds (`kVideoPlayThreshold`, `kVideoPauseThreshold`,
  `kVideoStealThreshold`) are all in `lib/utils/constants.dart`.

### 5.7 Theme

- Material 3 only (`useMaterial3: true`). Do not use `Theme.of(context).accentColor`
  or other M2-only APIs.
- Custom theme extensions: `CommentTheme` (depth-colored comment indent lines)
  and `MediaViewerTheme` (full-screen overlay colours). Access via:
  ```dart
  Theme.of(context).extension<CommentTheme>()!
  ```
- Font family is **Roboto** (bundled in `assets/fonts/`). Do not reference
  system fonts by name.

---

## 6. Linter Configuration

Preset: `very_good_analysis` (strict). Key active rules beyond the preset:

| Rule | Status | Effect |
|---|---|---|
| `public_member_api_docs` | **off** | Doc comments are not required on every public member |
| `require_trailing_commas` | **on** | Every argument/parameter list must have a trailing comma |
| `avoid_print` | **on** | Use `developer.log` instead of `print` |

Generated files (`*.g.dart`, `*.freezed.dart`) and `build/**` are excluded
from analysis.

---

## 7. Testing

- **Framework**: `flutter_test` + `mocktail` for mocking.
- **Mocking**: implement `Mock` from `mocktail`, not `Mockito`. Do not use
  `@GenerateMocks`.
- **`createdUtc` in tests**: pass `DateTime.utc(year)` or `DateTime.now()` — 
  never raw `double` epoch values.
- **Post constructors in tests**: `Post(...)` is no longer `const` (because
  `DateTime` is not a compile-time constant). Remove `const` from test Post
  constructions.
- Tests live under `test/notifiers/` (unit) and `test/widgets/` (widget).
- The top-level `test/widget_test.dart` is a smoke test — it is intentionally
  skipped and should not be removed.

---

## 8. Git Conventions

- Branch: `main` (single branch, squash-merge preferred).
- Commit format: `<type>: <short description>` where type is one of:
  `fix`, `feat`, `refactor`, `docs`, `test`, `chore`.
- All 16 files changed in the quality-improvement session are already committed
  in `a6c4840`.

---

## 9. Known Constraints & Trade-offs

| Constraint | Reason |
|---|---|
| `ProxyProvider` uses `prev ?? Foo(dep)` | Services hold mutable state; must not be recreated on rebuild. See comment in `main.dart`. |
| `VisibilityDetectorController.updateInterval` set once in `main()` | Previously overwritten per-player causing a race condition. |
| `RedditService` has no `BuildContext` | Keeps it testable in pure Dart; image precaching stays in `HomeScreen`. |
| `HistoryService` uses a `static late final Box` | Hive box is opened once at startup (`HistoryService.init()`) and shared across all instances. |
| `PostRepository` is a near-pass-through layer | Exists for testability (mockable boundary between notifiers and the API). |

---

## 10. Adding New Features — Checklist

1. **Model**: add to `lib/models/`, annotate `@immutable`, implement `copyWith`,
   `operator==`, `hashCode`. If it has a `createdUtc`, use `DateTime`.
2. **Parser**: if converting from a DRAW type, add/extend a parser in
   `lib/utils/parsers/` or `lib/utils/post_parser.dart`. Convert timestamps at
   the boundary.
3. **Service**: wrap all API calls in `_withAuthRetry`. Log with `developer.log`.
   Never call `SharedPreferences.getInstance()` — use the injected `_prefs`.
4. **Repository**: delegate to the service. Add the method to the interface for
   mockability in tests.
5. **Notifier**: guard `if (_repository == null) return;`. Expose
   `isLoading` + `errorMessage`. Don't call `notifyListeners()` in constructor.
6. **Widget**: use `context.select` for subscriptions. Add `mounted` checks
   after all `await`s. Add trailing commas everywhere.
7. **Wire DI**: add to `MultiProvider` in `main.dart` following the singleton
   `prev ?? Foo(dep)` pattern for services.
8. **Run**: `dart format lib/ test/` → `flutter analyze` → `flutter test`.
   All three must pass clean before committing.
