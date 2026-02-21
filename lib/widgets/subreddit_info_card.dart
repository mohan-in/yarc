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
                // Name + member count — takes all remaining space, pushes
                // the button to the trailing edge.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FadingText(
                        text: 'r/${subreddit.displayName}',
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
                const SizedBox(width: 8),
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

/// Single-line text that fades out on the trailing edge **only when** the text
/// overflows the available width. Short names render with no gradient.
class _FadingText extends StatelessWidget {
  const _FadingText({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedStyle =
            style?.merge(DefaultTextStyle.of(context).style) ??
            DefaultTextStyle.of(context).style;

        // Measure the text at single-line to see if it actually overflows.
        final painter = TextPainter(
          text: TextSpan(text: text, style: resolvedStyle),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final overflows = painter.width > constraints.maxWidth;

        final child = Text(
          text,
          style: style,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        );

        if (!overflows) {
          return child;
        }

        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            stops: [0.0, 0.75, 1.0],
            colors: [Colors.white, Colors.white, Colors.transparent],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: child,
        );
      },
    );
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

    // A fixed-width container keeps the card layout stable during the
    // transition between states — no layout jumps as the button swaps.
    return SizedBox(
      width: 96,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: _isLoading
            ? const Center(
                key: ValueKey<String>('loading'),
                child: SizedBox(
                  width: 20,
                  height: 20,
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
                    Icon(Icons.check, size: 14),
                    SizedBox(width: 4),
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
                    Icon(Icons.add, size: 14),
                    SizedBox(width: 4),
                    Text('Join'),
                  ],
                ),
              ),
      ),
    );
  }
}
