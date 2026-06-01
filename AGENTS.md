# AGENTS.md — Rules for AI Agents

Rules every AI agent **must follow** when working on this codebase.
No exceptions unless the rule itself says otherwise.

---

## Before You Touch Any Code

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

- All providers live inside `MultiProvider` in the root app widget's `build` method
- Services use `ProxyProvider` with `prev ?? Foo(dep)` — **never change this pattern**; services are intentional singletons that must not be recreated on rebuild
- Notifiers receive their repository via `..setRepository(repo)` in the `update` callback, not the constructor

---

## Dart Language Rules

- **Never** use `print` — use `developer.log(msg, name: 'ClassName')` from `dart:developer`
- **Never** use a bare `catch` or `catch (e)` — always `on SomeException catch (e)`
- **Always** wrap fire-and-forget futures with `unawaited()`: `unawaited(someNotifier.load())`
- **Always** use named parameters for constructors with ≥ 2 fields
- **Always** add trailing commas on every argument and parameter list (linter enforces this)
- New app-wide constants go in `lib/utils/constants.dart` with a `k` prefix (e.g. `kMyConst`)
- Use Dart record typedefs for result types: `typedef ItemsResult = ({List<Item> items, String? nextCursor})`

---

## Model Rules

- Every model must be annotated `@immutable`
- Every model must implement `operator==`, `hashCode`, and `copyWith`
- Factory constructors handle all external-type-to-domain conversion — domain models never reference external SDK types directly
- Timestamps are always `DateTime` (UTC) — convert from raw API values at the parse boundary, never store raw `double` or `int` epoch seconds

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

- Wrap all API calls in an auth-retry helper that catches 401/403, refreshes the session, and retries once
- Inject all external dependencies (e.g. `SharedPreferences`) via the constructor — never call their singletons (`.getInstance()`) inside a service
- If the service performs OAuth, the `state` parameter must be a `Random.secure()` 128-bit value — never a hardcoded string

---

## Widget Rules

- Use `context.select<Notifier, T>((n) => n.field)` for state subscriptions — never `context.watch` on a large notifier
- Use `context.read<Notifier>()` only inside callbacks (not in `build`)
- Add `if (!mounted) return;` after every `await` in `State` methods
- Widget classes used only within their own file must be private (`_MyWidget`)
- Exported widgets must be listed in a barrel file (e.g. `lib/widgets/widgets.dart`)
- Material 3 APIs only — do not use `Theme.of(context).accentColor` or any M2-only APIs
- Never reference system fonts by name — use only fonts declared in `pubspec.yaml`
- Access custom theme extensions as: `Theme.of(context).extension<MyThemeExtension>()!`

---

## Media / Resource ID Rules

- Never derive a widget's unique runtime ID from a URL or other shared value — two widgets can share the same URL (e.g. crossposts) and will collide
- Construct per-instance IDs using `identityHashCode(this)` combined with a content hash

---

## Testing Rules

- Use `mocktail` (`Mock`) for mocking — never `Mockito` or `@GenerateMocks`
- `DateTime` fields in test data must use `DateTime.utc(year)` or `DateTime.now()` — never raw `double` epoch values
- Do not use `const` on model constructors in tests when any field is a `DateTime` (it is not a compile-time constant)

---

## Git Rules

- Commit format: `<type>: <short description>`
- Valid types: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`
- One commit per logical change — do not bundle unrelated fixes

---

## Adding a New Feature — Required Steps in Order

1. **Model** → `lib/models/`: add `@immutable`, `copyWith`, `operator==`, `hashCode`; use `DateTime` for timestamps
2. **Parser / Mapper** → convert external SDK types to domain models at the boundary; never let raw SDK types leak into domain models
3. **Service** → `lib/services/`: wrap all API calls in the auth-retry helper; inject dependencies, never call singletons
4. **Repository** → `lib/repositories/`: delegate to service; keep the interface mockable
5. **Notifier** → `lib/notifiers/`: guard with `if (_repository == null) return;`; expose `isLoading` + `errorMessage`
6. **Widget** → use `context.select`; add `mounted` checks; trailing commas everywhere
7. **Wire DI** → add to `MultiProvider` in `main.dart`; use `prev ?? Foo(dep)` for services
8. **Verify** → `dart format lib/ test/` + `flutter analyze` + `flutter test` — all must be clean
