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
import 'package:yarc/widgets/post_list.dart';

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
  RedditorInfo? _userInfo;
  bool _isLoadingInfo = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadUserInfo());
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
      create: (_) => FeedNotifier()..selectSubreddit('u_${widget.username}'),
      update: (_, repo, settings, notifier) => notifier!
        ..setRepository(repo)
        ..setSettings(settings),
      child: Scaffold(
        appBar: AppBar(
          title: Text('u/${widget.username}'),
        ),
        body: Column(
          children: [
            _UserProfileHeader(
              userInfo: _userInfo,
              isLoading: _isLoadingInfo,
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(
                builder: (feedContext) {
                  return RefreshIndicator(
                    onRefresh: () => feedContext.read<FeedNotifier>().refresh(),
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    displacement: 20,
                    child: CustomScrollView(
                      slivers: [
                        _UserProfileFeed(
                          postRepository: context.read<PostRepository>(),
                        ),
                      ],
                    ),
                  );
                },
              ),
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
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (userInfo == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('User not found or error loading info.'),
      );
    }

    final theme = Theme.of(context);
    final cakeDay = userInfo!.createdUtc;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(
            label: 'Post Karma',
            value: userInfo!.linkKarma.toString(),
            icon: Icons.post_add,
            color: theme.colorScheme.primary,
          ),
          _StatColumn(
            label: 'Comment Karma',
            value: userInfo!.commentKarma.toString(),
            icon: Icons.comment,
            color: theme.colorScheme.secondary,
          ),
          if (cakeDay != null)
            _StatColumn(
              label: 'Cake Day',
              value:
                  '${cakeDay.year}-'
                  '${cakeDay.month.toString().padLeft(2, '0')}-'
                  '${cakeDay.day.toString().padLeft(2, '0')}',
              icon: Icons.cake,
              color: theme.colorScheme.tertiary,
            ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
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
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
