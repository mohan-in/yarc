import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/models.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/post_repository.dart';
import 'package:yarc/widgets/widgets.dart';

/// A full-screen feed for a single subreddit.
///
/// Uses a scoped, local [FeedNotifier] (via [ChangeNotifierProxyProvider2])
/// so it is completely isolated from the global home-screen feed.
/// Pressing back returns to whatever screen pushed this one
/// (e.g. Popular Subreddits) without disturbing the home feed.
///
/// Construct with a full [Subreddit] object when available (preserves icon,
/// subscriber count, etc.) or use [SubredditFeedScreen.fromName] when only
/// the subreddit name string is at hand.
class SubredditFeedScreen extends StatefulWidget {
  /// Push a feed screen with full [Subreddit] metadata.
  const SubredditFeedScreen({
    required Subreddit subreddit,
    super.key,
  }) : _subreddit = subreddit,
       _subredditName = null;

  /// Push a feed screen from a bare subreddit name (e.g. from a post header).
  ///
  /// Subreddit metadata (icon, subscriber count, etc.) will be fetched lazily
  /// by [FeedNotifier] once the repository is available.
  const SubredditFeedScreen.fromName({
    required String name,
    super.key,
  }) : _subreddit = null,
       _subredditName = name;

  final Subreddit? _subreddit;
  final String? _subredditName;

  /// Display name used for the AppBar title and [FeedNotifier] initialisation.
  String get _displayName => _subreddit?.displayName ?? _subredditName ?? '';

  @override
  State<SubredditFeedScreen> createState() => _SubredditFeedScreenState();
}

class _SubredditFeedScreenState extends State<SubredditFeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  FeedNotifier _createNotifier() {
    final notifier = FeedNotifier();
    final sub = widget._subreddit;
    if (sub != null) {
      notifier.selectSubredditWithInfo(sub);
    } else {
      notifier.selectSubreddit(widget._subredditName);
    }
    return notifier;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<
      PostRepository,
      SettingsNotifier,
      FeedNotifier
    >(
      create: (_) => _createNotifier(),
      update: (_, repo, settings, notifier) => notifier!
        ..setRepository(repo)
        ..setSettings(settings),
      child: Scaffold(
        appBar: AppBar(
          title: Text('r/${widget._displayName}'),
          actions: [
            UniversalAppBarActions(
              onScrollToTop: () => scrollToTop(_scrollController),
            ),
          ],
        ),
        body: _SubredditFeedBody(scrollController: _scrollController),
      ),
    );
  }
}

class _SubredditFeedBody extends StatelessWidget {
  const _SubredditFeedBody({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final errorMessage = context.select<FeedNotifier, String?>(
      (n) => n.errorMessage,
    );
    final posts = context.select<FeedNotifier, List<Post>>(
      (n) => n.visiblePosts,
    );
    final isLoading = context.select<FeedNotifier, bool>(
      (n) => n.isLoading,
    );

    return PaginatedScrollBody(
      controller: scrollController,
      onLoadMore: () => unawaited(context.read<FeedNotifier>().loadPosts()),
      onRefresh: () {
        context.read<FeedNotifier>().clearError();
        return context.read<FeedNotifier>().refresh();
      },
      slivers: [
        if (errorMessage != null && posts.isEmpty)
          SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          )
        else if (posts.isEmpty && !isLoading)
          const SliverFillRemaining(
            child: Center(
              child: Text('No posts found.'),
            ),
          )
        else
          const FeedSliver(),
      ],
    );
  }
}
