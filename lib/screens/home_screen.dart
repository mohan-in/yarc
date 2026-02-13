import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import '../utils/feed_utils.dart';
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
    // PostFrameCallback ensures we have access to Providers after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuth();
    });
  }

  Future<void> _initializeAuth() async {
    // context.read() is used to access providers without listening to changes
    final authNotifier = context.read<AuthNotifier>();
    final feedNotifier = context.read<FeedNotifier>();
    final subredditsNotifier = context.read<SubredditsNotifier>();

    await authNotifier.init();
    if (authNotifier.isLoggedIn && mounted) {
      unawaited(feedNotifier.loadPosts());
      unawaited(subredditsNotifier.fetch());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) {
      return;
    }

    final currentPosition = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;

    // Infinite scroll: Load more posts when user is close to the bottom
    if (currentPosition >= maxScroll - kPaginationThreshold) {
      unawaited(context.read<FeedNotifier>().loadPosts());
    }

    // Video autoplay: Notify the manager to check which video is visible
    context.read<VideoAutoplayNotifier>().notifyScroll();

    // Image precaching: Prefetch images for smoother scrolling
    if ((currentPosition - _lastPrecachePosition).abs() >=
        kPrecacheScrollThreshold) {
      _lastPrecachePosition = currentPosition;
      _precachePostImages();
    }
  }

  void _precachePostImages() {
    final feedNotifier = context.read<FeedNotifier>();
    final posts = feedNotifier.visiblePosts;

    // Delegate complex precaching logic to utility class
    FeedUtils.precachePostImages(
      context,
      posts,
      _scrollController.position.pixels,
    );
  }

  Future<void> _handleLogin() async {
    final authNotifier = context.read<AuthNotifier>();
    final error = await authNotifier.login();

    if (!mounted) {
      return;
    }

    if (error == null) {
      unawaited(context.read<FeedNotifier>().loadPosts());
      unawaited(context.read<SubredditsNotifier>().fetch());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleLogout() async {
    await context.read<AuthNotifier>().logout();
    if (!mounted) {
      return;
    }
    context.read<FeedNotifier>().clear();
    context.read<SubredditsNotifier>().clear();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.watch() rebuilds this widget when the provider notifies listeners
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
            // CustomScrollView allows mixing different scrollable areas (Slivers)
            controller: _scrollController,
            slivers: [
              // SliverAppBar floats above the content and can snap/hide
              SliverAppBar(
                floating: true,
                title: Text(
                  feedNotifier.currentSubreddit != null
                      ? 'r/${feedNotifier.currentSubreddit}'
                      : (authNotifier.isLoggedIn ? 'Home' : 'YARC'),
                ),
                actions: _buildAppBarActions(
                  context,
                  authNotifier,
                  feedNotifier,
                ),
              ),

              // Show login prompt if not logged in and not viewing a specific subreddit
              if (!authNotifier.isLoggedIn &&
                  feedNotifier.currentSubreddit == null)
                SliverFillRemaining(child: LoginPrompt(onLogin: _handleLogin))
              else
                // SliverPostList efficiently renders the list of posts
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
    BuildContext context,
    AuthNotifier authNotifier,
    FeedNotifier feedNotifier,
  ) {
    return [
      if (authNotifier.isLoggedIn || feedNotifier.currentSubreddit != null) ...[
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _openSearch(context),
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

  Future<void> _openSearch(BuildContext context) async {
    final selectedSubreddit = await showSearch<Subreddit?>(
      context: context,
      delegate: SubredditSearchDelegate(),
    );

    if (selectedSubreddit != null && context.mounted) {
      context.read<FeedNotifier>().selectSubredditWithInfo(selectedSubreddit);
    }
  }
}
