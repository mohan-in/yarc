import 'package:flutter/material.dart';
import 'package:yarc/models/comment.dart';
import 'package:yarc/theme/theme.dart';
import 'package:yarc/utils/date_utils.dart';
import 'package:yarc/utils/html_utils.dart';
import 'package:yarc/widgets/markdown_content.dart';

class CommentTile extends StatefulWidget {
  const CommentTile({required this.comment, super.key, this.depth = 0});

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
    final colorScheme = theme.colorScheme;
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

    final nextDepth = widget.depth + 1;
    final depthColor = depthColors[widget.depth % depthColors.length];

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comment Content
        InkWell(
          onTap: _toggleCollapse,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'u/${widget.comment.author}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateUtilsHelper.formatTimeAgo(
                              widget.comment.createdUtc,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (_isCollapsed) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.expand_more,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.comment.replies.length} replies',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (!_isCollapsed) ...[
                        const SizedBox(height: 4),
                        ...widget.comment.body
                            .split(RegExp(r'\n\s*\n'))
                            .where((p) => p.trim().isNotEmpty)
                            .expand(
                              (p) => [
                                MarkdownContent(
                                  text: HtmlUtils.unescape(p.trim()),
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 6),
                              ],
                            )
                            .toList()
                          ..removeLast(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (!_isCollapsed && widget.comment.replies.isNotEmpty)
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Container(
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
                      children: widget.comment.replies
                          .map(
                            (reply) =>
                                CommentTile(comment: reply, depth: nextDepth),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
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
