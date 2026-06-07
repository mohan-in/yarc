# AGENTS.md — Rules for AI Agents

Rules every AI agent **must follow** when working on this codebase.
No exceptions unless the rule itself says otherwise.

---

## Before You Touch Any Code

- Always end a session by running: `dart format lib/ test/` → `flutter analyze` → `flutter test`
- **Zero** analysis issues permitted — warnings are treated as errors under `very_good_analysis`.
- Never commit or declare success if any of those three commands fail.

---

## Layer Rules — Never Cross These Boundaries

- **Services** (`lib/services/`) must never import `flutter` or accept `BuildContext`.
- **Repositories** (`lib/repositories/`) call services only — no direct API or DB access.
- **Notifiers** (`lib/notifiers/`) call repositories only — no service imports.
- **Widgets / Screens** call notifiers via Provider — never import services or repositories directly.
- New code must go in the correct architectural layer; do not add logic to the wrong one.

---

## Dependency Injection & Assembly

- All global providers live in **[`providers.dart`](file:///home/mohan/Flutter/Projects/yarc/lib/di/providers.dart)** and are wired into `MultiProvider` in `YarcApp`'s `build` method.
- Services use `ProxyProvider` with the `prev ?? Foo(dep)` pattern to ensure they remain singletons and are not recreated on rebuilds.
- Notifiers receive their repository via `..setRepository(repo)` in the `update` callback of `ChangeNotifierProxyProvider`, not in the constructor.

---

## Dart Language Rules

- **Never** use `print` — use `developer.log(msg, name: 'ClassName')` from `dart:developer`.
- **Never** use a bare `catch` or `catch (e)` — always catch typed exceptions (`on SomeException catch (e)`).
- **Always** wrap fire-and-forget futures with `unawaited()` from `dart:async`.
- **Always** use named parameters for constructors with ≥ 2 fields.
- **Always** add trailing commas on every argument and parameter list.
- New app-wide constants go in `lib/utils/constants.dart` with a `k` prefix (e.g. `kMyConst`).
- Use Dart record typedefs for complex return types: `typedef ItemsResult = ({List<Item> items, String? nextCursor})`.

---

## Model Rules

- Every model must be annotated `@immutable`.
- Every model must implement `operator ==`, `hashCode`, and `copyWith`.
- Factory constructors handle all external-type-to-domain conversion — domain models must never reference external SDK types directly.
- Timestamps must always be `DateTime` (UTC) — parsed at boundary, never stored as raw epoch numbers.

---

## Notifier Rules

- Every notifier starts with `_repository == null` — wire it via `setRepository(repo)`.
- **Guard every public method**: `if (_repository == null) return;`.
- Every `async` operation must: set `_isLoading = true` + `notifyListeners()`, do work, then clear in a `finally` block.
- Errors surface via a nullable `_errorMessage` field + getter — **never throw** from a notifier.
- **Never** call `notifyListeners()` in a constructor body.
- `dispose()` must cancel all `StreamSubscription`s and close all `StreamController`s with `unawaited()`.
- Instance-level `StreamController`s only — no `static` streams.

---

## Widget & UI Rules

- Use `context.select<Notifier, T>((n) => n.field)` for state subscriptions — never `context.watch` on a large notifier.
- Use `context.read<Notifier>()` only inside callbacks (not in `build`).
- Add `if (!mounted) return;` after every `await` in `State` methods.
- Widget classes used only within their own file must be private (`_MyWidget`).
- Exported widgets must be listed in a barrel file (e.g. `lib/widgets/widgets.dart`).
- Material 3 APIs only — do not use `Theme.of(context).accentColor` or M2 APIs.
- Never reference system fonts by name — use only fonts declared in `pubspec.yaml`.
- Access custom theme extensions as: `Theme.of(context).extension<MyThemeExtension>()!`.

---

## Testing Rules

- Use `mocktail` (`Mock`) for mocking — never `Mockito` or `@GenerateMocks`.
- **Centralized Mocks**: Register standard mock definitions in **[`mocks.dart`](file:///home/mohan/Flutter/Projects/yarc/test/helpers/mocks.dart)**. Do not redeclare duplicate Mock classes inside individual test files.
- `DateTime` fields in test data must use `DateTime.utc(year)` or `DateTime.now()` — never raw epoch values.
- Do not use `const` on model constructors in tests when any field is a `DateTime`.

---

## Git Rules

- Commit format: `<type>: <short description>`
- Valid types: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`
- One commit per logical change — do not bundle unrelated changes together.

---

## Optimizing for Agentic AI (AI-Pairing Guidelines)

To make this codebase easy for Agentic AIs to reason about and work with:

1. **Explicit Over Implicit**: Avoid implicit state mutations. Write clear, documented side-effects.
2. **Decoupled Architecture**: Keep business logic (like app lifecycle changes or secure flags) separated from the main entrypoint (`main.dart`). Use dedicated widgets/notifiers (like `_SecureWindowWrapper`) for scoped behaviors.
3. **Small Context Footprints**: Avoid building massive files. Keep notifiers, repositories, and UI widgets focused on a single responsibility to prevent flooding context windows.
4. **Strong Typing & Records**: Use strongly-typed records and classes for data boundaries. Do not pass untyped dynamic maps through multiple architectural layers.
5. **Mockability**: Keep constructors clean and dependency-injected to ensure the AI can mock them trivially in tests.
