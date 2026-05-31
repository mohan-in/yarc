import 'dart:async';

import 'package:dex_compat/dex_compat.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:yarc/notifiers/notifiers.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/repositories.dart';
import 'package:yarc/screens/home_screen.dart';
import 'package:yarc/screens/post_detail_screen.dart';
import 'package:yarc/services/services.dart';
import 'package:yarc/theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set once globally — previously overwritten by every RedditVideoPlayer
  // initState, causing a race where the last initialised player "won".
  VisibilityDetectorController.instance.updateInterval = const Duration(
    milliseconds: 100,
  );

  await HistoryService.init();
  final isDesktopMode = await DexCompat.isDesktopMode();
  final prefs = await SharedPreferences.getInstance();

  final themeNotifier = ThemeNotifier();
  await themeNotifier.init();

  runApp(
    ChangeNotifierProvider.value(
      value: themeNotifier,
      child: YarcApp(
        isDesktopMode: isDesktopMode,
        prefs: prefs,
      ),
    ),
  );
}

class YarcApp extends StatefulWidget {
  const YarcApp({
    required this.isDesktopMode,
    required this.prefs,
    super.key,
  });

  final bool isDesktopMode;
  final SharedPreferences prefs;

  @override
  State<YarcApp> createState() => _YarcAppState();
}

class _YarcAppState extends State<YarcApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<DeepLinkResult>? _linkSubscription;

  /// Pending deep link to process after providers are ready
  DeepLinkResult? _pendingDeepLink;

  @override
  void initState() {
    super.initState();
    unawaited(_initDeepLinks());
  }

  Future<void> _initDeepLinks() async {
    // Handle initial link (cold start)
    final initialLink = await _deepLinkService.getInitialLink();
    if (initialLink != null) {
      _pendingDeepLink = initialLink;
    }

    // Listen for incoming links (warm start)
    _linkSubscription = _deepLinkService.linkStream.listen(_handleDeepLink);
  }

  Future<void> _handleDeepLink(DeepLinkResult result) async {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    switch (result.type) {
      case DeepLinkType.subreddit:
        if (result.subreddit != null) {
          context.read<FeedNotifier>().selectSubreddit(result.subreddit);
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      case DeepLinkType.post:
        if (result.postId != null) {
          final messenger = ScaffoldMessenger.of(context)
            ..showSnackBar(const SnackBar(content: Text('Opening post...')));

          try {
            final redditService = context.read<RedditService>();
            final postRepository = context.read<PostRepository>();
            final post = await redditService.fetchPost(result.postId!);

            if (post != null && context.mounted) {
              if (result.subreddit != null) {
                context.read<FeedNotifier>().selectSubreddit(result.subreddit);
                _navigatorKey.currentState?.popUntil((route) => route.isFirst);
              }

              unawaited(
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(
                      post: post,
                      postRepository: postRepository,
                    ),
                  ),
                ),
              );
            } else if (context.mounted) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Failed to load post')),
              );
              if (result.subreddit != null) {
                context.read<FeedNotifier>().selectSubreddit(result.subreddit);
              }
            }
          } on Object catch (e) {
            if (context.mounted) {
              messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        }
      case DeepLinkType.user:
        if (result.username != null) {
          context.read<FeedNotifier>().selectSubreddit(
            'u_${result.username}',
          );
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      case DeepLinkType.home:
        context.read<FeedNotifier>().selectSubreddit(null);
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      case DeepLinkType.unknown:
        break;
    }
  }

  @override
  void dispose() {
    unawaited(_linkSubscription?.cancel());
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService(widget.prefs)),
        Provider(create: (_) => HistoryService()),
        ChangeNotifierProvider(
          create: (_) => SettingsNotifier(widget.prefs),
        ),
        // ── Singleton services ───────────────────────────────────────────
        // Each service is created exactly once for the lifetime of the app.
        // The `prev ?? Foo(dep)` pattern means: reuse the existing instance if
        // one already exists, otherwise create it now. This is intentional:
        //
        // • These objects hold mutable state (auth tokens, caches, streams)
        //   that must survive across ProxyProvider rebuilds without being
        //   reset.
        // • ProxyProvider rebuilds whenever an upstream provider changes, but
        //   that should NOT recreate the service and wipe its state.
        //
        // ⚠️  Known trade-off: if AuthService itself were ever recreated (e.g.
        // during a future refactor that makes it non-singleton), RedditService
        // and AuthRepository would keep references to the *old* AuthService.
        // If that happens, switch to `create:` / `Provider` or add explicit
        // re-creation logic here.
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
      ],
      child: Builder(
        builder: (context) {
          if (_pendingDeepLink != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pendingDeepLink != null) {
                unawaited(_handleDeepLink(_pendingDeepLink!));
                _pendingDeepLink = null;
              }
            });
          }

          final themeNotifier = context.watch<ThemeNotifier>();

          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'YARC - Yet Another Reddit Client',
            theme: appTheme,
            darkTheme: darkAppTheme,
            themeMode: themeNotifier.themeMode,
            home: const HomeScreen(),
            builder: DexCompat.builder(widget.isDesktopMode),
          );
        },
      ),
    );
  }
}
