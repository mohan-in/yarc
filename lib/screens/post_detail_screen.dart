import 'package:flutter/material.dart';
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/services/reddit_service.dart';
import 'package:yarc/widgets/comment_list.dart';
import 'package:yarc/widgets/post_card.dart';

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
