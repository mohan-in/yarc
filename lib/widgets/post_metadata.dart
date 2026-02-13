import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/date_utils.dart';

/// A widget displaying post metadata: time, comments, upvotes, and external link.
class PostMetadata extends StatelessWidget {
  const PostMetadata({
    super.key,
    required this.createdUtc,
    required this.numComments,
    required this.ups,
    required this.permalink,
  });

  final double createdUtc;
  final int numComments;
  final int ups;
  final String permalink;

  Future<void> _copyUrl(BuildContext context) async {
    final String url = 'https://www.reddit.com$permalink';
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post URL copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateUtilsHelper.formatTimeAgo(createdUtc),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () => _copyUrl(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Copy post URL',
            ),
            const SizedBox(width: 16),
            const Icon(Icons.mode_comment_outlined, size: 16),
            const SizedBox(width: 4),
            Text('$numComments'),
            const SizedBox(width: 16),
            const Icon(Icons.arrow_upward, size: 16),
            const SizedBox(width: 4),
            Text('$ups'),
          ],
        ),
      ],
    );
  }
}
