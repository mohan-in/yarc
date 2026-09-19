import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/subreddits_notifier.dart';
import 'package:yarc/notifiers/top_subreddits_notifier.dart';
import 'package:yarc/utils/image_utils.dart';
import 'package:yarc/utils/number_format_utils.dart';

/// Displays the most popular subreddits, loaded lazily page by page.
class TopSubredditsScreen extends StatefulWidget {
  const TopSubredditsScreen({super.key});

  @override
  State<TopSubredditsScreen> createState() => _TopSubredditsScreenState();
}

class _TopSubredditsScreenState extends State<TopSubredditsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TopSubredditsView(scrollController: _scrollController);
  }
}

class _TopSubredditsView extends StatefulWidget {
  const _TopSubredditsView({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_TopSubredditsView> createState() => _TopSubredditsViewState();
}

class _TopSubredditsViewState extends State<_TopSubredditsView> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<TopSubredditsNotifier>().loadNextPage());
    });
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(context.read<TopSubredditsNotifier>().loadNextPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Popular Subreddits'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<TopSubredditsNotifier>().refresh(),
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: _TopSubredditsList(
          scrollController: widget.scrollController,
        ),
      ),
    );
  }
}

class _TopSubredditsList extends StatelessWidget {
  const _TopSubredditsList({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final subreddits = context.select<TopSubredditsNotifier, List<Subreddit>>(
      (n) => n.subreddits,
    );
    final isLoading = context.select<TopSubredditsNotifier, bool>(
      (n) => n.isLoading,
    );
    final errorMessage = context.select<TopSubredditsNotifier, String?>(
      (n) => n.errorMessage,
    );
    final hasMore = context.select<TopSubredditsNotifier, bool>(
      (n) => n.hasMore,
    );

    if (subreddits.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (subreddits.isEmpty && errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  context.read<TopSubredditsNotifier>().clearError();
                  unawaited(
                    context.read<TopSubredditsNotifier>().loadNextPage(),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final itemCount =
        subreddits.length +
        (isLoading || (hasMore && subreddits.isNotEmpty) ? 1 : 0);

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView.separated(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: bottomInset),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        if (index >= subreddits.length) {
          // Bottom loading indicator
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _SubredditListTile(
          subreddit: subreddits[index],
        );
      },
    );
  }
}

class _SubredditListTile extends StatelessWidget {
  const _SubredditListTile({
    required this.subreddit,
  });

  final Subreddit subreddit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () {
        // Select this subreddit on the global FeedNotifier, then pop back
        // to HomeScreen so the user lands directly on the subreddit feed.
        context.read<FeedNotifier>().selectSubredditWithInfo(subreddit);
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      leading: _SubredditAvatar(subreddit: subreddit),
      title: Text(
        'r/${subreddit.displayName}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subreddit.subscriberCount != null
          ? Row(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 3),
                Text(
                  NumberFormatUtils.formatCompact(
                    subreddit.subscriberCount!,
                    suffix: ' members',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          : null,
      trailing: _JoinLeaveButton(subreddit: subreddit),
    );
  }
}

class _SubredditAvatar extends StatelessWidget {
  const _SubredditAvatar({required this.subreddit});

  final Subreddit subreddit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = subreddit.iconImg;

    if (icon != null) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(
          ImageUtils.getCorsUrl(icon),
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(
        Icons.reddit,
        color: colorScheme.onPrimaryContainer,
      ),
    );
  }
}

/// Join / Leave button for toggling subreddit subscription on this screen.
class _JoinLeaveButton extends StatefulWidget {
  const _JoinLeaveButton({required this.subreddit});

  final Subreddit subreddit;

  @override
  State<_JoinLeaveButton> createState() => _JoinLeaveButtonState();
}

class _JoinLeaveButtonState extends State<_JoinLeaveButton> {
  bool _isLoading = false;

  Future<void> _toggle() async {
    setState(() => _isLoading = true);
    try {
      await context.read<SubredditsNotifier>().toggleSubscription(
        widget.subreddit,
      );
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update subscription')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubscribed = context.select<SubredditsNotifier, bool>(
      (n) => n.isSubscribed(widget.subreddit.displayName),
    );

    return SizedBox(
      width: 88,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: _isLoading
            ? const Center(
                key: ValueKey<String>('loading'),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : isSubscribed
            ? OutlinedButton(
                key: const ValueKey<String>('joined'),
                onPressed: _toggle,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, size: 13),
                    SizedBox(width: 3),
                    Text('Joined'),
                  ],
                ),
              )
            : FilledButton(
                key: const ValueKey<String>('join'),
                onPressed: _toggle,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 13),
                    SizedBox(width: 3),
                    Text('Join'),
                  ],
                ),
              ),
      ),
    );
  }
}
