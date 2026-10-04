import 'package:flutter/foundation.dart';
import 'package:yarc/models/vote_type.dart';

@immutable
class Comment {
  const Comment({
    required this.id,
    required this.author,
    required this.body,
    required this.ups,
    required this.createdUtc,
    this.replies = const [],
    this.voteType = VoteType.none,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String? ?? '',
    author: json['author'] as String? ?? '',
    body: json['body'] as String? ?? '',
    ups: json['ups'] as int? ?? 0,
    createdUtc:
        DateTime.tryParse(json['createdUtc'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
    replies:
        (json['replies'] as List<dynamic>?)
            ?.map((r) => Comment.fromJson(r as Map<String, dynamic>))
            .toList() ??
        const [],
    voteType: VoteType.values.firstWhere(
      (v) => v.name == json['voteType'],
      orElse: () => VoteType.none,
    ),
  );

  Comment copyWith({
    String? id,
    String? author,
    String? body,
    int? ups,
    DateTime? createdUtc,
    List<Comment>? replies,
    VoteType? voteType,
  }) {
    return Comment(
      id: id ?? this.id,
      author: author ?? this.author,
      body: body ?? this.body,
      ups: ups ?? this.ups,
      createdUtc: createdUtc ?? this.createdUtc,
      replies: replies ?? this.replies,
      voteType: voteType ?? this.voteType,
    );
  }

  final String id;
  final String author;
  final String body;
  final int ups;
  final DateTime createdUtc;
  final List<Comment> replies;
  final VoteType voteType;

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'body': body,
    'ups': ups,
    'createdUtc': createdUtc.toIso8601String(),
    'replies': replies.map((r) => r.toJson()).toList(),
    'voteType': voteType.name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Comment &&
          other.id == id &&
          other.ups == ups &&
          other.voteType == voteType);

  @override
  int get hashCode => Object.hash(id, ups, voteType);
}
