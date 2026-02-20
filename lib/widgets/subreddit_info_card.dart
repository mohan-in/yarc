import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/notifiers/subreddits_notifier.dart';
import 'package:yarc/utils/image_utils.dart';

/// A card displaying subreddit information at the top of the feed.
class SubredditInfoCard extends StatelessWidget {
  const SubredditInfoCard({required this.subreddit, super.key});

  final Subreddit subreddit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (subreddit.iconImg != null)
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: CachedNetworkImageProvider(
                      ImageUtils.getCorsUrl(subreddit.iconImg!),
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.group,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'r/${subreddit.displayName}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subreddit.subscriberCount != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatSubscriberCount(
                                subreddit.subscriberCount!,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                _JoinLeaveButton(subreddit: subreddit),
              ],
            ),
            if (subreddit.description != null &&
                subreddit.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(subreddit.description!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSubscriberCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M members';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K members';
    }
    return '$count members';
  }
}

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

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (isSubscribed) {
      return OutlinedButton.icon(
        onPressed: _toggle,
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Joined'),
      );
    }

    return FilledButton.icon(
      onPressed: _toggle,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Join'),
    );
  }
}
