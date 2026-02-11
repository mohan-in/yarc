import 'package:flutter/material.dart';
import '../models/comment.dart';

import '../widgets/comment_tile.dart';

/// A widget that loads and displays comments for a post.
///
/// It handles the loading state, error state, and empty state.
/// Depending on where it is used (e.g., inside CustomScrollView),
/// it can return a generic widget or a Sliver.
class CommentList extends StatelessWidget {
  final Future<List<Comment>> commentsFuture;

  const CommentList({super.key, required this.commentsFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Comment>>(
      future: commentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading spinner while fetching comments
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          // Show an error message if something goes wrong
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}'),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Show a message if there are no comments
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No comments yet.'),
              ),
            ),
          );
        } else {
          // Efficiently render the list of comments
          // SliverList is better for performance than ListView when part of a CustomScrollView
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              return CommentTile(comment: snapshot.data![index]);
            }, childCount: snapshot.data!.length),
          );
        }
      },
    );
  }
}
