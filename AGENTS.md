# AGENTS.md — Rules for AI Agents

Rules every AI agent **must follow** when working on this codebase.
No exceptions unless the rule itself says otherwise.

---

## Before You Touch Any Code

- Run from the project root: `/home/mohan/Flutter/Projects/yarc`
- Always end a session with `dart format lib/ test/` → `flutter analyze` → `flutter test`
- **Zero** analysis issues permitted — warnings are errors under `very_good_analysis`
- Never commit if any of those three commands fail

---

## Layer Rules — Never Cross These Boundaries

- **Services** (`lib/services/`) must never import `flutter` or accept `BuildContext`
- **Repositories** (`lib/repositories/`) call services only — no direct API or DB access
- **Notifiers** (`lib/notifiers/`) call repositories only — no service imports
- **Widgets / Screens** call notifiers via Provider — never import services or repositories directly
- New code goes in the correct layer; do not add logic to the wrong one

---

## Dependency Injection (`main.dart`)

- All providers live in `_YarcAppState.build()` inside `MultiProvider`
- Services use `ProxyProvider` with `prev ?? Foo(dep)` — **never change this pattern**; services are intentional singletons that must not be recreated on rebuild
- Notifiers receive their repository via `..setRepository(repo)` in the `update` callback, not the constructor

---

## Dart Language Rules

- **Never** use `print` — use `developer.log(msg, name: 'ClassName')` from `dart:developer`
- **Never** use a bare `catch` or `catch (e)` — always `on SomeException catch (e)`
- **Always** wrap fire-and-forget futures with `unawaited()`: `unawaited(feedNotifier.loadPosts())`
- **Always** use named parameters for constructors with ≥ 2 fields
- **Always** add trailing commas on every argument and parameter list (linter enforces this)
- New app-wide constants go in `lib/utils/constants.dart` with a `k` prefix (e.g. `kMyConst`)
- Use Dart record typedefs for result types: `typedef PostsResult = ({List<Post> posts, String? nextAfter})`

---

## Model Rules

- Every model must be annotated `@immutable`
- Every model must implement `operator==`, `hashCode`, and `copyWith`
- Factory constructors (`fromDraw(...)`) handle all DRAW-to-domain conversion — domain models never reference DRAW types
- Timestamps are always `DateTime` (UTC) — convert from raw API values at the parse boundary, never store `double` epoch seconds

---

## Notifier Rules

- Every notifier starts with `_repository == null` — wire it via `setRepository(repo)`
- **Guard every public method**: `if (_repository == null) return;`
- Every `async` operation must: set `_isLoading = true` + `notifyListeners()`, do work, then clear in a `finally` block
- Errors surface via a nullable `_errorMessage` field + getter — **never throw** from a notifier
- **Never** call `notifyListeners()` in a constructor body
- `dispose()` must cancel all `StreamSubscription`s and close all `StreamController`s with `unawaited()`
- Instance-level `StreamController`s only — no `static` streams

---

## Service Rules

- Every `RedditService` API method must be wrapped in `_withAuthRetry(actionName, action)`
- `AuthService` uses injected `SharedPreferences _prefs` — **never** call `SharedPreferences.getInstance()` inside any service
- OAuth `state` must be a `Random.secure()` 128-bit value — never a hardcoded string

---

## Widget Rules

- Use `context.select<Notifier, T>((n) => n.field)` for state subscriptions — never `context.watch` on a large notifier
- Use `context.read<Notifier>()` only inside callbacks (not in `build`)
- Add `if (!mounted) return;` after every `await` in `State` methods
- Widget classes used only within their own file must be private (`_MyWidget`)
- Exported widgets must be listed in `lib/widgets/widgets.dart`
- Material 3 APIs only — do not use `Theme.of(context).accentColor` or any M2-only APIs
- Theme font is **Roboto** (bundled) — do not reference system fonts by name
- Access custom theme extensions as: `Theme.of(context).extension<CommentTheme>()!`

---

## Video Player Rule

- Each player's `_playerId` must be `'${identityHashCode(this)}_${widget.videoUrl.hashCode}'`
- **Never** use `widget.videoUrl` alone as an ID — crossposts share URLs and will collide

---

## Testing Rules

- Use `mocktail` (`Mock`) for mocking — never `Mockito` or `@GenerateMocks`
- `createdUtc` in test data must be `DateTime.utc(year)` or `DateTime.now()` — never a raw `double`
- `Post(...)` constructors in tests must not be `const` (DateTime is not a compile-time constant)
- Do not remove `test/widget_test.dart` — it is an intentional skipped smoke test

---

## Git Rules

- Commit format: `<type>: <short description>`
- Valid types: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`
- One commit per logical change — do not bundle unrelated fixes

---

## Adding a New Feature — Required Steps in Order

1. **Model** → `lib/models/`: add `@immutable`, `copyWith`, `operator==`, `hashCode`; use `DateTime` for timestamps
2. **Parser** → `lib/utils/parsers/`: convert DRAW types to domain models; convert timestamps at this boundary only
3. **Service** → `lib/services/`: wrap all API calls in `_withAuthRetry`; use injected `_prefs`, not `getInstance()`
4. **Repository** → `lib/repositories/`: delegate to service; keep mockable
5. **Notifier** → `lib/notifiers/`: guard with `if (_repository == null) return;`; expose `isLoading` + `errorMessage`
6. **Widget** → use `context.select`; add `mounted` checks; trailing commas everywhere
7. **Wire DI** → add to `MultiProvider` in `main.dart`; use `prev ?? Foo(dep)` for services
8. **Verify** → `dart format lib/ test/` + `flutter analyze` + `flutter test` — all must be clean
