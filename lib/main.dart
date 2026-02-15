import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/notifiers/notifiers.dart';
import 'package:yarc/repositories/repositories.dart';
import 'package:yarc/screens/home_screen.dart';
import 'package:yarc/screens/post_detail_screen.dart';
import 'package:yarc/services/services.dart';
import 'package:yarc/theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HistoryService.init();

  runApp(const YarcApp());
}

class YarcApp extends StatefulWidget {
  const YarcApp({super.key});

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
            ..showSnackBar(
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
          } on Object catch (e) {
            if (context.mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        }
      case DeepLinkType.user:
        break;
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
                unawaited(_handleDeepLink(_pendingDeepLink!));
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
