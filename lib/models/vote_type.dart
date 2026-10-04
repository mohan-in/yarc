/// Represents the user's vote state on a post or comment.
enum VoteType {
  /// The user has not cast a vote.
  none,

  /// The user has upvoted the item.
  upvoted,

  /// The user has downvoted the item.
  downvoted,
}
