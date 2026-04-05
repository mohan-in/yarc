import 'package:flutter/material.dart';
import 'package:yarc/models/models.dart';
import 'package:yarc/repositories/repositories.dart';
import 'package:yarc/widgets/comment_list.dart';
import 'package:yarc/widgets/post_card.dart';

/// The scrollable body content for a post detail view.
///
/// Renders the post card (expanded), crosspost section, comments header,
/// and comments list inside a [CustomScrollView]. This is used in both
/// the standalone `PostDetailScreen` and the right pane of the
/// master-detail layout on wide screens.
class PostDetailContent extends StatefulWidget {
  const PostDetailContent({
    required this.post,
    required this.postRepository,
    super.key,
  });

  final Post post;
  final PostRepository postRepository;

  @override
  State<PostDetailContent> createState() => _PostDetailContentState();
}

class _PostDetailContentState extends State<PostDetailContent> {
  late Future<List<Comment>> _commentsFuture;

  @override
  void initState() {
    super.initState();
    _commentsFuture = widget.postRepository.getComments(widget.post.id);
  }

  @override
  void didUpdateWidget(PostDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch comments when the displayed post changes.
    if (oldWidget.post.id != widget.post.id) {
      _commentsFuture = widget.postRepository.getComments(widget.post.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crosspostParent = widget.post.crosspostParent;

    return CustomScrollView(
      slivers: [
        // Post content
        SliverToBoxAdapter(
          child: PostCard(post: widget.post, expanded: true),
        ),

        // Original post for crossposts
        if (crosspostParent != null)
          SliverToBoxAdapter(
            child: _OriginalPostSection(originalPost: crosspostParent),
          ),

        // Comments Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Comments',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),

        // Comments List
        CommentList(commentsFuture: _commentsFuture),
      ],
    );
  }
}

class _OriginalPostSection extends StatelessWidget {
  const _OriginalPostSection({required this.originalPost});

  final Post originalPost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.repeat,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Original Post',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        PostCard(post: originalPost, expanded: true),
      ],
    );
  }
}
