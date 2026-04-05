import 'package:flutter/material.dart';
import 'package:yarc/models/models.dart';
import 'package:yarc/repositories/repositories.dart';
import 'package:yarc/widgets/widgets.dart';

/// A full-screen page for viewing a single post's details and comments.
///
/// On narrow (phone) screens this is pushed as a route.
/// The actual content is rendered by [PostDetailContent].
class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({
    required this.post,
    required this.postRepository,
    super.key,
  });

  final Post post;
  final PostRepository postRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            title: Text('r/${post.subreddit}'),
          ),
        ],
        body: PostDetailContent(
          post: post,
          postRepository: postRepository,
        ),
      ),
    );
  }
}
