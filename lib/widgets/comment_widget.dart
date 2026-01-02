import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../utils/html_utils.dart';
import 'markdown_content.dart';

class CommentWidget extends StatefulWidget {
  final Comment comment;
  final int depth;

  const CommentWidget({super.key, required this.comment, this.depth = 0});

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> {
  bool _isCollapsed = false;

  void _toggleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only indentation for depth > 0 to avoid wasted space
    Widget content = Padding(
      padding: EdgeInsets.only(left: widget.depth == 0 ? 0.0 : 2.0, top: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.2),
                  width: 2.0,
                ),
              ),
            ),
            padding: const EdgeInsets.only(left: 4.0, right: 8.0, bottom: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _toggleCollapse,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'u/${widget.comment.author}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_isCollapsed) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.expand_more, size: 16),
                          ],
                        ],
                      ),
                      // Upvote count removed
                    ],
                  ),
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(height: 4),
                  ...widget.comment.body
                      .split(RegExp(r'\n\s*\n'))
                      .where((p) => p.trim().isNotEmpty)
                      .expand(
                        (p) => [
                          MarkdownContent(text: HtmlUtils.unescape(p.trim())),
                          const SizedBox(
                            height: 6,
                          ), // Reduced paragraph spacing
                        ],
                      )
                      .toList()
                    ..removeLast(), // Remove trailing SizedBox
                ],
              ],
            ),
          ),
          if (!_isCollapsed && widget.comment.replies.isNotEmpty)
            Column(
              children: widget.comment.replies
                  .map(
                    (reply) =>
                        CommentWidget(comment: reply, depth: widget.depth + 1),
                  )
                  .toList(),
            ),
        ],
      ),
    );

    if (widget.depth == 0) {
      return Card(
        // Add vertical spacing between thread cards
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: content,
      );
    }

    return content;
  }
}
