import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_state.dart';
import '../providers/feed_state.dart';
import '../providers/subreddits_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/login_prompt.dart';
import '../widgets/post_list.dart';
import '../widgets/subreddit_search_delegate.dart';
import '../utils/image_utils.dart';
import 'post_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Prefetch threshold: Start loading next page when 800px from bottom
  // This is roughly 2-3 cards ahead, giving seamless infinite scroll
  static const int _scrollThreshold = 800;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Initialize auth on startup
    Future.microtask(() async {
      await ref.read(authProvider.notifier).init();
      final authState = ref.read(authProvider);
      if (authState.isLoggedIn) {
        ref.read(feedProvider.notifier).loadPosts();
        ref.read(subredditsProvider.notifier).fetchSubreddits();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Track last precache scroll position to throttle precaching
  double _lastPrecachePosition = 0;
  static const double _precacheScrollThreshold =
      600; // Precache every 600px of scroll

  void _scrollListener() {
    final currentPosition = _scrollController.position.pixels;

    // Load more posts when near bottom
    if (currentPosition >=
        _scrollController.position.maxScrollExtent - _scrollThreshold) {
      ref.read(feedProvider.notifier).loadPosts();
    }

    // Precache images as user scrolls (throttled to every 600px)
    if ((currentPosition - _lastPrecachePosition).abs() >=
        _precacheScrollThreshold) {
      _lastPrecachePosition = currentPosition;
      _precachePostImages();
    }
  }

  Future<void> _handleLogin() async {
    final success = await ref.read(authProvider.notifier).login();
    if (success) {
      ref.read(feedProvider.notifier).loadPosts();
      ref.read(subredditsProvider.notifier).fetchSubreddits();
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(feedProvider.notifier).clear();
    ref.read(subredditsProvider.notifier).clear();
  }

  /// Precaches images for upcoming posts (not yet visible).
  /// Uses CachedNetworkImage's cache manager for disk caching.
  void _precachePostImages() {
    final posts = ref.read(feedProvider).visiblePosts;

    // Calculate roughly which posts are visible (estimate ~3 posts per screen)
    final scrollPosition = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;
    final estimatedVisibleIndex = (scrollPosition / 300)
        .floor(); // ~300px per card

    // Prefetch next 5 posts beyond the visible area
    final startIndex = (estimatedVisibleIndex + 3).clamp(0, posts.length);
    final endIndex = (startIndex + 5).clamp(0, posts.length);

    for (var i = startIndex; i < endIndex; i++) {
      final post = posts[i];

      // Collect all image URLs for this post (carousel or single image)
      final imagesToCache = <String>[];

      // Add carousel images
      if (post.images.isNotEmpty) {
        imagesToCache.addAll(post.images);
      }
      // Add single image if exists and not already in carousel
      else if (post.imageUrl != null) {
        imagesToCache.add(post.imageUrl!);
      }
      // Add thumbnail as fallback
      else if (post.thumbnail != null) {
        imagesToCache.add(post.thumbnail!);
      }

      // Precache all images for this post
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
    final authState = ref.watch(authProvider);
    final feedState = ref.watch(feedProvider);
    final subreddits = ref.watch(subredditsProvider);
    final redditService = ref.read(redditServiceProvider);

    // Precache when posts change or user scrolls
    ref.listen(feedProvider, (previous, next) {
      if (next.posts.length > (previous?.posts.length ?? 0)) {
        _precachePostImages();
      }
    });

    // Handle back gesture: go to home feed if viewing a subreddit
    return PopScope(
      canPop: feedState.currentSubreddit == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && feedState.currentSubreddit != null) {
          ref.read(feedProvider.notifier).selectSubreddit(null);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            feedState.currentSubreddit != null
                ? 'r/${feedState.currentSubreddit}'
                : (authState.isLoggedIn ? 'Home' : 'YARC'),
          ),
          actions: _buildAppBarActions(authState, feedState),
        ),
        drawer: !authState.isLoggedIn
            ? null
            : AppDrawer(
                subreddits: subreddits,
                onSubredditSelected: (sub) {
                  ref
                      .read(feedProvider.notifier)
                      .selectSubreddit(sub.displayName);
                },
                onLogout: _handleLogout,
              ),
        body: _buildBody(authState, feedState, redditService),
      ),
    );
  }

  List<Widget> _buildAppBarActions(AuthState authState, FeedState feedState) {
    return [
      if (feedState.currentSubreddit != null)
        IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            ref.read(feedProvider.notifier).selectSubreddit(null);
          },
          tooltip: 'Go Home',
        ),
      if (authState.isLoggedIn || feedState.currentSubreddit != null) ...[
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _openSearch,
          tooltip: 'Search Subreddits',
        ),
        IconButton(
          icon: Icon(
            feedState.hideRead ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            ref.read(feedProvider.notifier).toggleHideRead();
            _scrollToTop();
          },
          tooltip: feedState.hideRead ? 'Show All Posts' : 'Hide Read Posts',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.read(feedProvider.notifier).refresh();
            _scrollToTop();
          },
        ),
      ],
      if (!authState.isLoggedIn)
        TextButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Login'),
          onPressed: _handleLogin,
          style: TextButton.styleFrom(foregroundColor: Colors.black),
        ),
    ];
  }

  Future<void> _openSearch() async {
    final selectedSubreddit = await showSearch<String?>(
      context: context,
      delegate: SubredditSearchDelegate(ref: ref),
    );

    if (selectedSubreddit != null) {
      ref.read(feedProvider.notifier).selectSubreddit(selectedSubreddit);
    }
  }

  Widget _buildBody(
    AuthState authState,
    FeedState feedState,
    dynamic redditService,
  ) {
    // Show login prompt if not logged in and no subreddit selected
    if (!authState.isLoggedIn && feedState.currentSubreddit == null) {
      return LoginPrompt(onLogin: _handleLogin);
    }

    // Show post list
    return PostList(
      posts: feedState.visiblePosts,
      isLoading: feedState.isLoading,
      scrollController: _scrollController,
      onRefresh: () => ref.read(feedProvider.notifier).refresh(),
      onPostTap: (post) {
        ref.read(feedProvider.notifier).markAsRead(post.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PostDetailScreen(post: post, redditService: redditService),
          ),
        );
      },
    );
  }
}
