import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/vote_type.dart';
import 'package:yarc/notifiers/comments_notifier.dart';
import 'package:yarc/theme/theme.dart';
import 'package:yarc/utils/date_utils.dart';
import 'package:yarc/widgets/markdown_content.dart';

class CommentTile extends StatefulWidget {
  const CommentTile({
    required this.comment,
    super.key,
    this.depth = 0,
  });

  final Comment comment;
  final int depth;

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _isCollapsed = false;

  void _toggleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentTheme = theme.extension<CommentTheme>();
    final depthColors =
        commentTheme?.depthColors ??
        [
          Colors.red,
          Colors.orange,
          Colors.amber,
          Colors.green,
          Colors.blue,
          Colors.indigo,
          Colors.purple,
        ];

    final depthColor = depthColors[widget.depth % depthColors.length];
    final nextDepth = widget.depth + 1;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _toggleCollapse,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CommentHeader(
                  comment: widget.comment,
                  isCollapsed: _isCollapsed,
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _isCollapsed
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      _CommentBody(body: widget.comment.body),
                      _CommentActions(comment: widget.comment),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _isCollapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: const SizedBox.shrink(),
          secondChild: widget.comment.replies.isNotEmpty
              ? _CommentReplies(
                  replies: widget.comment.replies,
                  depth: nextDepth,
                  depthColor: depthColor,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );

    if (widget.depth == 0) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: content,
      );
    }

    return content;
  }
}

/// Displays the comment author, timestamp, score, and collapse indicator.
class _CommentHeader extends StatelessWidget {
  const _CommentHeader({
    required this.comment,
    required this.isCollapsed,
  });

  final Comment comment;
  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          'u/${comment.author}',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          DateUtilsHelper.formatTimeAgo(comment.createdUtc),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '• ${comment.ups} pts',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: comment.voteType != VoteType.none
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        if (isCollapsed) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.expand_more,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '${comment.replies.length} replies',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Action bar for voting on a comment.
class _CommentActions extends StatelessWidget {
  const _CommentActions({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(
            comment.voteType == VoteType.upvoted
                ? Icons.arrow_upward
                : Icons.arrow_upward_outlined,
            size: 16,
            color: comment.voteType == VoteType.upvoted
                ? colorScheme.primary
                : colorScheme.outline,
          ),
          onPressed: () {
            unawaited(
              context.read<CommentsNotifier>().voteComment(
                comment,
                VoteType.upvoted,
              ),
            );
          },
          tooltip: 'Upvote comment',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        Text(
          '${comment.ups}',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: comment.voteType != VoteType.none
                ? FontWeight.bold
                : FontWeight.normal,
            color: comment.voteType == VoteType.upvoted
                ? colorScheme.primary
                : (comment.voteType == VoteType.downvoted
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant),
          ),
        ),
        IconButton(
          icon: Icon(
            comment.voteType == VoteType.downvoted
                ? Icons.arrow_downward
                : Icons.arrow_downward_outlined,
            size: 16,
            color: comment.voteType == VoteType.downvoted
                ? colorScheme.error
                : colorScheme.outline,
          ),
          onPressed: () {
            unawaited(
              context.read<CommentsNotifier>().voteComment(
                comment,
                VoteType.downvoted,
              ),
            );
          },
          tooltip: 'Downvote comment',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }
}

/// Renders the comment body as markdown paragraphs.
class _CommentBody extends StatelessWidget {
  const _CommentBody({required this.body});

  /// Pre-compiled regex for splitting comment body into paragraphs.
  static final _paragraphSplitRegex = RegExp(r'\n\s*\n');

  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paragraphs = body
        .split(_paragraphSplitRegex)
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          MarkdownContent(
            text: paragraphs[i].trim(),
            style: theme.textTheme.bodyMedium,
          ),
          if (i < paragraphs.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

/// Renders nested comment replies with a depth-colored left border.
class _CommentReplies extends StatelessWidget {
  const _CommentReplies({
    required this.replies,
    required this.depth,
    required this.depthColor,
  });

  final List<Comment> replies;
  final int depth;
  final Color depthColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: depthColor.withAlpha(128),
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: replies
            .map(
              (reply) => CommentTile(comment: reply, depth: depth),
            )
            .toList(),
      ),
    );
  }
}
