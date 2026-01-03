import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_state.dart';
import '../providers/feed_state.dart';
import '../providers/subreddits_state.dart';
import '../widgets/post_card.dart';
import '../widgets/app_drawer.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          feedState.currentSubreddit != null
              ? 'r/${feedState.currentSubreddit}'
              : (authState.isLoggedIn ? 'Home Feed' : 'YARC'),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
              icon: Icon(
                feedState.hideRead ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                ref.read(feedProvider.notifier).toggleHideRead();
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              tooltip: feedState.hideRead
                  ? 'Show All Posts'
                  : 'Hide Read Posts',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(feedProvider.notifier).refresh();
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
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
        ],
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
      body: !authState.isLoggedIn && feedState.currentSubreddit == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.reddit, size: 80, color: Colors.deepOrange),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome to YARC',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _handleLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('Login with Reddit'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : feedState.visiblePosts.isEmpty && feedState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => ref.read(feedProvider.notifier).refresh(),
              child: ListView.builder(
                controller: _scrollController,
                itemCount:
                    feedState.visiblePosts.length +
                    (feedState.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == feedState.visiblePosts.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final post = feedState.visiblePosts[index];
                  return PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    onTap: () {
                      ref.read(feedProvider.notifier).markAsRead(post.id);
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
                  );
                },
              ),
            ),
    );
  }
}
