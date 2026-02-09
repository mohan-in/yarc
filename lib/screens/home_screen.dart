import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/reddit_service.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/feed_notifier.dart';
import '../notifiers/subreddits_notifier.dart';
import '../notifiers/video_autoplay_notifier.dart';
import '../models/subreddit.dart';
import '../widgets/app_drawer.dart';
import '../widgets/login_prompt.dart';
import '../widgets/post_list.dart';
import '../widgets/subreddit_search_delegate.dart';
import '../utils/constants.dart';
import '../utils/image_utils.dart';
import 'post_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  double _lastPrecachePosition = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuth();
    });
  }

  Future<void> _initializeAuth() async {
    final authNotifier = context.read<AuthNotifier>();
    final feedNotifier = context.read<FeedNotifier>();
    final subredditsNotifier = context.read<SubredditsNotifier>();
    await authNotifier.init();
    if (authNotifier.isLoggedIn && mounted) {
      feedNotifier.loadPosts();
      subredditsNotifier.fetch();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final currentPosition = _scrollController.position.pixels;

    if (currentPosition >=
        _scrollController.position.maxScrollExtent - kPaginationThreshold) {
      context.read<FeedNotifier>().loadPosts();
    }

    context.read<VideoAutoplayNotifier>().notifyScroll();

    if ((currentPosition - _lastPrecachePosition).abs() >=
        kPrecacheScrollThreshold) {
      _lastPrecachePosition = currentPosition;
      _precachePostImages();
    }
  }

  Future<void> _handleLogin() async {
    final authNotifier = context.read<AuthNotifier>();
    final error = await authNotifier.login();

    if (!mounted) return;

    if (error == null) {
      context.read<FeedNotifier>().loadPosts();
      context.read<SubredditsNotifier>().fetch();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleLogout() async {
    await context.read<AuthNotifier>().logout();
    if (!mounted) return;
    context.read<FeedNotifier>().clear();
    context.read<SubredditsNotifier>().clear();
  }

  /// Precaches images for upcoming posts (not yet visible).
  /// Uses CachedNetworkImage's cache manager for disk caching.
  void _precachePostImages() {
    final feedNotifier = context.read<FeedNotifier>();
    final posts = feedNotifier.visiblePosts;

    final scrollPosition = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    final estimatedVisibleIndex = (scrollPosition / kEstimatedPostCardHeight)
        .floor();

    final startIndex = (estimatedVisibleIndex + kVisiblePostsBeforePrefetch)
        .clamp(0, posts.length);
    final endIndex = (startIndex + kPrefetchPostCount).clamp(0, posts.length);

    for (var i = startIndex; i < endIndex; i++) {
      final post = posts[i];

      // Collect all image URLs for this post (carousel or single image)
      final imagesToCache = <String>[];

      if (post.images.isNotEmpty) {
        imagesToCache.addAll(post.images);
      } else if (post.imageUrl != null) {
        imagesToCache.add(post.imageUrl!);
      } else if (post.thumbnail != null) {
        imagesToCache.add(post.thumbnail!);
      }

      for (final imageUrl in imagesToCache) {
        precacheImage(
          CachedNetworkImageProvider(
            ImageUtils.getCorsUrl(imageUrl),
            headers: ImageUtils.authHeaders,
          ),
          context,
        ).catchError((_) {});
      }
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = context.watch<AuthNotifier>();
    final feedNotifier = context.watch<FeedNotifier>();
    final subredditsNotifier = context.watch<SubredditsNotifier>();
    final redditService = context.read<RedditService>();

    return PopScope(
      canPop: feedNotifier.currentSubreddit == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && feedNotifier.currentSubreddit != null) {
          context.read<FeedNotifier>().selectSubreddit(null);
        }
      },
      child: Scaffold(
        drawer: !authNotifier.isLoggedIn
            ? null
            : AppDrawer(
                subreddits: subredditsNotifier.subreddits,
                currentSubreddit: feedNotifier.currentSubreddit,
                onSubredditSelected: (sub) {
                  if (sub == null) {
                    context.read<FeedNotifier>().selectSubreddit(null);
                  } else {
                    context.read<FeedNotifier>().selectSubredditWithInfo(sub);
                  }
                  _scrollToTop();
                  Navigator.pop(context);
                },
                onLogout: _handleLogout,
              ),
        body: RefreshIndicator(
          onRefresh: () => context.read<FeedNotifier>().refresh(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                floating: true,
                title: Text(
                  feedNotifier.currentSubreddit != null
                      ? 'r/${feedNotifier.currentSubreddit}'
                      : (authNotifier.isLoggedIn ? 'Home' : 'YARC'),
                ),
                actions: _buildAppBarActions(authNotifier, feedNotifier),
              ),
              if (!authNotifier.isLoggedIn &&
                  feedNotifier.currentSubreddit == null)
                SliverFillRemaining(child: LoginPrompt(onLogin: _handleLogin))
              else
                SliverPostList(
                  posts: feedNotifier.visiblePosts,
                  isLoading: feedNotifier.isLoading,
                  subredditInfo: feedNotifier.currentSubredditInfo,
                  onPostTap: (post) {
                    context.read<FeedNotifier>().markAsRead(post.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailScreen(
                          post: post,
                          redditService: redditService,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions(
    AuthNotifier authNotifier,
    FeedNotifier feedNotifier,
  ) {
    return [
      if (authNotifier.isLoggedIn || feedNotifier.currentSubreddit != null) ...[
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _openSearch,
          tooltip: 'Search Subreddits',
        ),
        IconButton(
          icon: Icon(
            feedNotifier.hideRead ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            context.read<FeedNotifier>().toggleHideRead();
            _scrollToTop();
          },
          tooltip: feedNotifier.hideRead ? 'Show All Posts' : 'Hide Read Posts',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            context.read<FeedNotifier>().refresh();
            _scrollToTop();
          },
        ),
      ],
    ];
  }

  Future<void> _openSearch() async {
    final selectedSubreddit = await showSearch<Subreddit?>(
      context: context,
      delegate: SubredditSearchDelegate(),
    );

    if (selectedSubreddit != null && mounted) {
      context.read<FeedNotifier>().selectSubredditWithInfo(selectedSubreddit);
    }
  }
}
