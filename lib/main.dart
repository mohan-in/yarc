import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'theme/theme.dart';
import 'services/auth_service.dart';
import 'services/history_service.dart';
import 'services/reddit_service.dart';
import 'services/deep_link_service.dart';
import 'repositories/auth_repository.dart';
import 'repositories/post_repository.dart';
import 'repositories/subreddit_repository.dart';
import 'notifiers/auth_notifier.dart';
import 'notifiers/feed_notifier.dart';
import 'notifiers/search_notifier.dart';
import 'notifiers/subreddits_notifier.dart';
import 'notifiers/video_autoplay_notifier.dart';
import 'screens/home_screen.dart';
import 'screens/post_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HistoryService.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<DeepLinkResult>? _linkSubscription;

  /// Pending deep link to process after providers are ready
  DeepLinkResult? _pendingDeepLink;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
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
        break;
      case DeepLinkType.post:
        if (result.postId != null) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(
            const SnackBar(content: Text('Opening post...')),
          );

          try {
            final redditService = context.read<RedditService>();
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
                      redditService: redditService,
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
          } catch (e) {
            if (context.mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text('Error: ${e.toString()}')),
              );
            }
          }
        }
        break;
      case DeepLinkType.user:
        break;
      case DeepLinkType.home:
        context.read<FeedNotifier>().selectSubreddit(null);
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        break;
      case DeepLinkType.unknown:
        break;
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _deepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => HistoryService()),
        ProxyProvider<AuthService, RedditService>(
          update: (_, auth, prev) => RedditService(auth),
        ),

        ProxyProvider<AuthService, AuthRepository>(
          update: (_, auth, prev) => AuthRepository(auth),
        ),
        ProxyProvider2<RedditService, HistoryService, PostRepository>(
          update: (_, reddit, history, prev) => PostRepository(reddit, history),
        ),
        ProxyProvider<RedditService, SubredditRepository>(
          update: (_, reddit, prev) => SubredditRepository(reddit),
        ),

        ChangeNotifierProxyProvider<AuthRepository, AuthNotifier>(
          create: (_) => AuthNotifier(),
          update: (_, repo, notifier) => notifier!..setRepository(repo),
        ),
        ChangeNotifierProxyProvider<PostRepository, FeedNotifier>(
          create: (_) => FeedNotifier(),
          update: (_, repo, notifier) => notifier!..setRepository(repo),
        ),
        ChangeNotifierProxyProvider<SubredditRepository, SubredditsNotifier>(
          create: (_) => SubredditsNotifier(),
          update: (_, repo, notifier) => notifier!..setRepository(repo),
        ),
        ChangeNotifierProxyProvider<SubredditRepository, SearchNotifier>(
          create: (_) => SearchNotifier(),
          update: (_, repo, notifier) => notifier!..setRepository(repo),
        ),
        ChangeNotifierProvider(create: (_) => VideoAutoplayNotifier()),
      ],
      child: Builder(
        builder: (context) {
          if (_pendingDeepLink != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pendingDeepLink != null) {
                _handleDeepLink(_pendingDeepLink!);
                _pendingDeepLink = null;
              }
            });
          }

          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'YARC - Yet Another Reddit Client',
            theme: appTheme,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
