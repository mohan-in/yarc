import 'package:flutter/foundation.dart';
import 'package:yarc/models/comment.dart';
import 'package:yarc/models/vote_type.dart';
import 'package:yarc/repositories/post_repository.dart';

/// Notifier for managing, fetching, and refreshing post comments.
class CommentsNotifier extends ChangeNotifier {
  PostRepository? _repository;

  List<Comment> _comments = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentPostId;

  List<Comment> get comments => _comments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentPostId => _currentPostId;

  // Injected via ProxyProvider update callback.
  // ignore: use_setters_to_change_properties
  void setRepository(PostRepository repository) {
    _repository = repository;
  }

  /// Fetches comments for [postId].
  Future<List<Comment>> loadComments(String postId) async {
    if (_repository == null) {
      return [];
    }

    _currentPostId = postId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return _comments = await _repository!.getComments(postId);
    } on Exception catch (e) {
      _errorMessage = e.toString();
      _comments = [];
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes comments for the current post.
  Future<void> refresh() async {
    if (_repository == null || _currentPostId == null) {
      return;
    }
    await loadComments(_currentPostId!);
  }

  /// Casts or clears a vote on a comment with optimistic tree updates.
  Future<void> voteComment(Comment comment, VoteType targetVote) async {
    if (_repository == null) return;

    final oldVote = comment.voteType;
    final oldUps = comment.ups;
    final newVote = oldVote == targetVote ? VoteType.none : targetVote;

    var delta = 0;
    if (oldVote == VoteType.none) {
      delta = newVote == VoteType.upvoted
          ? 1
          : (newVote == VoteType.downvoted ? -1 : 0);
    } else if (oldVote == VoteType.upvoted) {
      delta = newVote == VoteType.none
          ? -1
          : (newVote == VoteType.downvoted ? -2 : 0);
    } else if (oldVote == VoteType.downvoted) {
      delta = newVote == VoteType.none
          ? 1
          : (newVote == VoteType.upvoted ? 2 : 0);
    }

    final updated = comment.copyWith(
      voteType: newVote,
      ups: oldUps + delta,
    );
    _updateCommentInTree(updated);
    notifyListeners();

    try {
      await _repository!.voteComment(
        commentId: comment.id,
        voteType: newVote,
      );
    } on Exception catch (e) {
      final reverted = comment.copyWith(
        voteType: oldVote,
        ups: oldUps,
      );
      _updateCommentInTree(reverted);
      _errorMessage = 'Failed to vote on comment: $e';
      notifyListeners();
    }
  }

  void _updateCommentInTree(Comment updated) {
    _comments = _updateCommentList(_comments, updated);
  }

  List<Comment> _updateCommentList(List<Comment> list, Comment target) {
    return list.map((c) {
      if (c.id == target.id) {
        return target;
      }
      if (c.replies.isNotEmpty) {
        return c.copyWith(
          replies: _updateCommentList(c.replies, target),
        );
      }
      return c;
    }).toList();
  }

  void clear() {
    _comments = [];
    _isLoading = false;
    _errorMessage = null;
    _currentPostId = null;
    notifyListeners();
  }
}
