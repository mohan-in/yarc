import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yarc/notifiers/notifiers.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/repositories.dart';
import 'package:yarc/services/services.dart';

/// Returns the complete list of providers for the dependency injection tree.
///
/// Order is critical: services are registered first, followed by repositories,
/// then notifiers that depend on those repositories.
List<SingleChildWidget> getAppProviders(SharedPreferences prefs) {
  return [
    Provider(create: (_) => AuthService(prefs)),
    Provider(create: (_) => HistoryService()),
    Provider(create: (_) => BiometricService()),
    ProxyProvider<BiometricService, BiometricRepository>(
      update: (_, service, prev) => prev ?? BiometricRepository(service),
    ),
    ChangeNotifierProvider(
      create: (_) => SettingsNotifier(prefs),
    ),
    ChangeNotifierProxyProvider<BiometricRepository, BiometricLockNotifier>(
      create: (_) => BiometricLockNotifier(),
      update: (_, repo, notifier) => notifier!..setRepository(repo),
    ),
    // ── Singleton services ───────────────────────────────────────────
    // Each service is created exactly once for the lifetime of the app.
    // The `prev ?? Foo(dep)` pattern means: reuse the existing instance if
    // one already exists, otherwise create it now.
    ProxyProvider<AuthService, RedditService>(
      update: (_, auth, prev) => prev ?? RedditService(auth),
    ),
    ProxyProvider<AuthService, AuthRepository>(
      update: (_, auth, prev) => prev ?? AuthRepository(auth),
    ),
    ProxyProvider2<RedditService, HistoryService, PostRepository>(
      update: (_, reddit, history, prev) =>
          prev ?? PostRepository(reddit, history),
    ),
    ProxyProvider<RedditService, SubredditRepository>(
      update: (_, reddit, prev) => prev ?? SubredditRepository(reddit),
    ),
    ChangeNotifierProxyProvider<AuthRepository, AuthNotifier>(
      create: (_) => AuthNotifier(),
      update: (_, repo, notifier) => notifier!..setRepository(repo),
    ),
    ChangeNotifierProxyProvider2<
      PostRepository,
      SettingsNotifier,
      FeedNotifier
    >(
      create: (_) => FeedNotifier(),
      update: (_, repo, settings, notifier) => notifier!
        ..setRepository(repo)
        ..setSettings(settings),
    ),
    ChangeNotifierProxyProvider<SubredditRepository, SubredditsNotifier>(
      create: (_) => SubredditsNotifier(),
      update: (_, repo, notifier) => notifier!..setRepository(repo),
    ),
    ChangeNotifierProxyProvider2<
      SubredditRepository,
      RedditService,
      SearchNotifier
    >(
      create: (_) => SearchNotifier(),
      update: (_, repo, reddit, notifier) => notifier!
        ..setRepository(repo)
        ..setRedditService(reddit),
    ),
    ChangeNotifierProvider(create: (_) => VideoAutoplayNotifier()),
  ];
}
