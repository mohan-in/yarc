import 'package:flutter/material.dart';
import 'package:yarc/models/models.dart';
import 'package:yarc/services/services.dart';
import 'package:yarc/widgets/widgets.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    required this.post,
    required this.redditService,
    super.key,
  });

  final Post post;
  final RedditService redditService;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Future<List<Comment>> _commentsFuture;

  @override
  void initState() {
    super.initState();
    // Start fetching comments as soon as the screen initializes
    _commentsFuture = widget.redditService.fetchComments(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    final crosspostParent = widget.post.crosspostParent;
    return Scaffold(
      body: CustomScrollView(
        // CustomScrollView enables complex
        // scrolling effects like the floating bar
        slivers: [
          SliverAppBar(pinned: true, title: Text('r/${widget.post.subreddit}')),

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
          // We extracted the complex loading logic into a separate widget
          CommentList(commentsFuture: _commentsFuture),
        ],
      ),
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
