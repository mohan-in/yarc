import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/redditor_info.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/post_repository.dart';
import 'package:yarc/screens/post_detail_screen.dart';
import 'package:yarc/services/reddit_service.dart';
import 'package:yarc/widgets/widgets.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    required this.username,
    super.key,
  });

  final String username;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  RedditorInfo? _userInfo;
  bool _isLoadingInfo = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadUserInfo());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    try {
      final redditService = context.read<RedditService>();
      final info = await redditService.fetchUser(widget.username);
      if (mounted) {
        setState(() {
          _userInfo = info;
          _isLoadingInfo = false;
        });
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingInfo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<
      PostRepository,
      SettingsNotifier,
      FeedNotifier
    >(
      create: (_) => FeedNotifier()..selectUserProfile(widget.username),
      update: (_, repo, settings, notifier) => notifier!
        ..setRepository(repo)
        ..setSettings(settings),
      child: Scaffold(
        appBar: AppBar(
          title: Text('u/${widget.username}'),
          actions: [
            UniversalAppBarActions(
              onScrollToTop: () {
                if (_scrollController.hasClients) {
                  unawaited(
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                  );
                }
              },
              showSearch: false,
            ),
          ],
        ),
        body: _UserProfileBody(
          userInfo: _userInfo,
          isLoadingInfo: _isLoadingInfo,
          scrollController: _scrollController,
        ),
      ),
    );
  }
}

class _UserProfileBody extends StatelessWidget {
  const _UserProfileBody({
    required this.userInfo,
    required this.isLoadingInfo,
    required this.scrollController,
  });

  final RedditorInfo? userInfo;
  final bool isLoadingInfo;
  final ScrollController scrollController;

  void _scrollListener(BuildContext context) {
    if (!scrollController.hasClients) return;

    final currentPosition = scrollController.position.pixels;
    final maxScroll = scrollController.position.maxScrollExtent;

    const threshold = 500.0;
    if (currentPosition >= maxScroll - threshold) {
      unawaited(context.read<FeedNotifier>().loadPosts());
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _scrollListener(context);
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => context.read<FeedNotifier>().refresh(),
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest,
        displacement: 20,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _UserProfileHeader(
                    userInfo: userInfo,
                    isLoading: isLoadingInfo,
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
            _UserProfileFeed(
              postRepository: context.read<PostRepository>(),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserProfileHeader extends StatelessWidget {
  const _UserProfileHeader({
    required this.userInfo,
    required this.isLoading,
  });

  final RedditorInfo? userInfo;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (userInfo == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text('User not found or error loading info.'),
      );
    }

    final theme = Theme.of(context);
    final cakeDay = userInfo!.createdUtc;
    final formattedCakeDay = cakeDay != null
        ? '${cakeDay.year}-'
              '${cakeDay.month.toString().padLeft(2, '0')}-'
              '${cakeDay.day.toString().padLeft(2, '0')}'
        : '';

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: Text(
              userInfo!.name.isNotEmpty ? userInfo!.name[0].toUpperCase() : '?',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'u/${userInfo!.name}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${userInfo!.totalKarma} total karma',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Post Karma',
                    value: userInfo!.linkKarma.toString(),
                    icon: Icons.post_add,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'Comment Karma',
                    value: userInfo!.commentKarma.toString(),
                    icon: Icons.comment,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                if (cakeDay != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      label: 'Cake Day',
                      value: formattedCakeDay,
                      icon: Icons.cake,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserProfileFeed extends StatelessWidget {
  const _UserProfileFeed({required this.postRepository});

  final PostRepository postRepository;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<FeedNotifier, bool>((n) => n.isLoading);
    final posts = context.select<FeedNotifier, List<Post>>(
      (n) => n.visiblePosts,
    );
    final readPostIds = context.select<FeedNotifier, Set<String>>(
      (n) => n.readPostIds,
    );

    return SliverPostList(
      posts: posts,
      isLoading: isLoading,
      readPostIds: readPostIds,
      onPostVisible: (post) {
        unawaited(context.read<FeedNotifier>().markAsRead(post.id));
      },
      onPostTap: (post) {
        unawaited(
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (context) => PostDetailScreen(
                post: post,
                postRepository: postRepository,
              ),
            ),
          ),
        );
      },
    );
  }
}
