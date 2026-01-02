import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/reddit_service.dart';
import '../services/auth_service.dart';
import '../models/post.dart';
import '../models/subreddit.dart';
import '../widgets/post_card.dart';
import '../widgets/app_drawer.dart';
import '../utils/image_utils.dart';
import 'post_detail_page.dart';

class RedditHomePage extends StatefulWidget {
  final RedditService? redditService;
  final AuthService? authService;

  const RedditHomePage({super.key, this.redditService, this.authService});

  @override
  State<RedditHomePage> createState() => _RedditHomePageState();
}

class _RedditHomePageState extends State<RedditHomePage> {
  late final RedditService _redditService;
  late final AuthService _authService;

  final List<Post> _posts = [];
  List<Subreddit> _subscribedSubreddits = [];
  String? _after;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  // If null, we use Home Feed (authenticated).
  String? _currentSubreddit;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _redditService =
        widget.redditService ?? RedditService(authService: _authService);
    _scrollController.addListener(_scrollListener);
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = _authService.isLoggedIn;
    setState(() {
      _isLoggedIn = loggedIn;
      _currentSubreddit = null;
      _posts.clear();
      _after = null;
    });
    if (loggedIn) {
      _loadPosts(); // Only load posts if logged in
      _fetchSubreddits();
    }
  }

  Future<void> _fetchSubreddits() async {
    try {
      final subs = await _redditService.fetchSubscribedSubreddits();
      subs.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      if (mounted) {
        setState(() {
          _subscribedSubreddits = subs;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch subreddits: $e');
    }
  }

  Future<void> _handleLogin() async {
    final success = await _authService.authenticate();
    if (success) {
      setState(() {
        _isLoggedIn = true;
        _currentSubreddit = null; // Switch to Home Feed
        _posts.clear();
        _after = null;
      });
      _loadPosts();
      _fetchSubreddits();
    }
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    setState(() {
      _isLoggedIn = false;
      _currentSubreddit = null;
      _posts.clear();
      _after = null;
      _subscribedSubreddits.clear();
    });
    // Do not load posts after logout, waiting for login
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPosts();
    }
  }

  Future<void> _loadPosts() async {
    // Prevent loading if not logged in and no subreddit selected (Guest mode on home)
    if (!_isLoggedIn && _currentSubreddit == null) return;

    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _redditService.fetchPosts(
        subreddit: _currentSubreddit,
        after: _after,
      );
      final newPosts = result.posts;
      _after = result.nextAfter;

      if (!mounted) return;

      // Precache images for new posts
      final Map<String, String>? headers = kIsWeb
          ? null
          : {'User-Agent': 'flutter_reddit_demo/1.0.0 (by /u/antigravity)'};

      for (var post in newPosts) {
        try {
          if (post.imageUrl != null) {
            precacheImage(
              NetworkImage(
                ImageUtils.getCorsUrl(post.imageUrl!),
                headers: headers,
              ),
              context,
            ).catchError((e) {
              debugPrint('Failed to precache image: $e');
            });
          } else if (post.thumbnail != null) {
            precacheImage(
              NetworkImage(
                ImageUtils.getCorsUrl(post.thumbnail!),
                headers: headers,
              ),
              context,
            ).catchError((e) {
              debugPrint('Failed to precache thumbnail: $e');
            });
          }
        } catch (e) {
          debugPrint('Failed to precache image: $e');
        }
      }

      setState(() {
        _posts.addAll(newPosts);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _refreshPosts() {
    setState(() {
      _posts.clear();
      _after = null;
    });
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentSubreddit != null
              ? 'r/$_currentSubreddit'
              : (_isLoggedIn ? 'Home Feed' : 'YARC'),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_currentSubreddit != null)
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                setState(() {
                  _currentSubreddit = null;
                  _posts.clear();
                  _after = null;
                });
                _loadPosts();
              },
              tooltip: 'Go Home',
            ),
          if (_isLoggedIn || _currentSubreddit != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshPosts,
            ),
          if (!_isLoggedIn)
            TextButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Login'),
              onPressed: _handleLogin,
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
        ],
      ),
      drawer: !_isLoggedIn
          ? null
          : AppDrawer(
              subreddits: _subscribedSubreddits,
              onSubredditSelected: (sub) {
                setState(() {
                  _currentSubreddit = sub.displayName;
                  _posts.clear();
                  _after = null;
                });
                _loadPosts();
              },
              onLogout: _handleLogout,
            ),
      body: !_isLoggedIn && _currentSubreddit == null
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
          : _posts.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _refreshPosts(),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _posts.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _posts.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final post = _posts[index];
                  return PostCard(
                    post: post,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailPage(
                            post: post,
                            redditService: _redditService,
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
