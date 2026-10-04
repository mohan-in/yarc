import 'package:flutter/foundation.dart';
import 'package:yarc/models/vote_type.dart';

/// Represents a parsed segment of a flair, either text or a custom emoji.
@immutable
class FlairItem {
  const FlairItem({
    required this.isEmoji,
    this.text,
    this.emojiUrl,
  });

  factory FlairItem.fromJson(Map<String, dynamic> json) => FlairItem(
    isEmoji: json['isEmoji'] as bool? ?? false,
    text: json['text'] as String?,
    emojiUrl: json['emojiUrl'] as String?,
  );

  final bool isEmoji;
  final String? text;
  final String? emojiUrl;

  FlairItem copyWith({
    bool? isEmoji,
    String? text,
    String? emojiUrl,
  }) {
    return FlairItem(
      isEmoji: isEmoji ?? this.isEmoji,
      text: text ?? this.text,
      emojiUrl: emojiUrl ?? this.emojiUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'isEmoji': isEmoji,
    if (text != null) 'text': text,
    if (emojiUrl != null) 'emojiUrl': emojiUrl,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlairItem &&
          other.isEmoji == isEmoji &&
          other.text == text &&
          other.emojiUrl == emojiUrl);

  @override
  int get hashCode => Object.hash(isEmoji, text, emojiUrl);
}

/// A data model representing a Reddit post.
@immutable
class Post {
  const Post({
    required this.id,
    required this.title,
    required this.author,
    required this.subreddit,
    required this.ups,
    required this.numComments,
    required this.permalink,
    required this.content,
    required this.createdUtc,
    this.thumbnail,
    this.imageUrl,
    this.images = const [],
    this.url,
    this.isVideo = false,
    this.videoUrl,
    this.isYoutube = false,
    this.youtubeId,
    this.aspectRatio,
    this.crosspostParent,
    this.authorFlairText,
    this.authorFlairRichtext,
    this.linkFlairText,
    this.linkFlairRichtext,
    this.totalAwardsReceived = 0,
    this.isSaved = false,
    this.isNsfw = false,
    this.isStickied = false,
    this.voteType = VoteType.none,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    author: json['author'] as String? ?? '',
    subreddit: json['subreddit'] as String? ?? '',
    ups: json['ups'] as int? ?? 0,
    numComments: json['numComments'] as int? ?? 0,
    permalink: json['permalink'] as String? ?? '',
    content: json['content'] as String? ?? '',
    createdUtc:
        DateTime.tryParse(json['createdUtc'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
    thumbnail: json['thumbnail'] as String?,
    imageUrl: json['imageUrl'] as String?,
    images: (json['images'] as List<dynamic>?)?.cast<String>() ?? const [],
    url: json['url'] as String?,
    isVideo: json['isVideo'] as bool? ?? false,
    videoUrl: json['videoUrl'] as String?,
    isYoutube: json['isYoutube'] as bool? ?? false,
    youtubeId: json['youtubeId'] as String?,
    aspectRatio: (json['aspectRatio'] as num?)?.toDouble(),
    crosspostParent: json['crosspostParent'] != null
        ? Post.fromJson(json['crosspostParent'] as Map<String, dynamic>)
        : null,
    authorFlairText: json['authorFlairText'] as String?,
    authorFlairRichtext: (json['authorFlairRichtext'] as List<dynamic>?)
        ?.map((e) => FlairItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    linkFlairText: json['linkFlairText'] as String?,
    linkFlairRichtext: (json['linkFlairRichtext'] as List<dynamic>?)
        ?.map((e) => FlairItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalAwardsReceived: json['totalAwardsReceived'] as int? ?? 0,
    isSaved: json['isSaved'] as bool? ?? false,
    isNsfw: json['isNsfw'] as bool? ?? false,
    isStickied: json['isStickied'] as bool? ?? false,
    voteType: VoteType.values.firstWhere(
      (v) => v.name == json['voteType'],
      orElse: () => VoteType.none,
    ),
  );

  /// The unique ID of the post (e.g., "t3_12345").
  final String id;

  final String title;

  /// The username of the author (without "u/").
  final String author;

  /// The subreddit name (without "r/").
  final String subreddit;

  final int ups;

  /// The URL of the thumbnail image, if available.
  final String? thumbnail;

  /// The URL of the main image, if available.
  final String? imageUrl;

  /// The permalink path to the post (e.g., "/r/flutter/comments/...").
  final String permalink;

  final int numComments;

  /// The textual content of the post (selftext).
  final String content;

  /// The creation time in UTC.
  final DateTime createdUtc;

  /// A list of image URLs for gallery posts.
  final List<String> images;

  final bool isVideo;

  final String? videoUrl;

  final bool isYoutube;

  final String? youtubeId;

  final double? aspectRatio;

  /// The external URL for link-type posts (non-self posts).
  final String? url;

  /// The original post for crossposts/reposts.
  final Post? crosspostParent;

  /// Whether this post is stickied (pinned) by a moderator.
  final bool isStickied;

  /// Whether the post is marked as NSFW.
  final bool isNsfw;

  /// The author's flair text (if any).
  final String? authorFlairText;

  /// The parsed richtext of the author's flair (if any).
  final List<FlairItem>? authorFlairRichtext;

  /// The post's flair text (if any).
  final String? linkFlairText;

  /// The parsed richtext of the post's flair (if any).
  final List<FlairItem>? linkFlairRichtext;

  /// The number of awards received.
  final int totalAwardsReceived;

  /// Whether the user has saved this post.
  final bool isSaved;

  /// The user's vote state on this post.
  final VoteType voteType;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'subreddit': subreddit,
    'ups': ups,
    'numComments': numComments,
    'permalink': permalink,
    'content': content,
    'createdUtc': createdUtc.toIso8601String(),
    if (thumbnail != null) 'thumbnail': thumbnail,
    if (imageUrl != null) 'imageUrl': imageUrl,
    'images': images,
    if (url != null) 'url': url,
    'isVideo': isVideo,
    if (videoUrl != null) 'videoUrl': videoUrl,
    'isYoutube': isYoutube,
    if (youtubeId != null) 'youtubeId': youtubeId,
    if (aspectRatio != null) 'aspectRatio': aspectRatio,
    if (crosspostParent != null) 'crosspostParent': crosspostParent!.toJson(),
    if (authorFlairText != null) 'authorFlairText': authorFlairText,
    if (authorFlairRichtext != null)
      'authorFlairRichtext': authorFlairRichtext!
          .map((e) => e.toJson())
          .toList(),
    if (linkFlairText != null) 'linkFlairText': linkFlairText,
    if (linkFlairRichtext != null)
      'linkFlairRichtext': linkFlairRichtext!.map((e) => e.toJson()).toList(),
    'totalAwardsReceived': totalAwardsReceived,
    'isSaved': isSaved,
    'isNsfw': isNsfw,
    'isStickied': isStickied,
    'voteType': voteType.name,
  };

  List<Object?> get props => [
    id,
    title,
    author,
    subreddit,
    ups,
    numComments,
    createdUtc,
    thumbnail,
    url,
    permalink,
    content,
    images,
    isVideo,
    videoUrl,
    isYoutube,
    youtubeId,
    aspectRatio,
    crosspostParent,
    isNsfw,
    isStickied,
    authorFlairText,
    linkFlairText,
    authorFlairRichtext,
    linkFlairRichtext,
    totalAwardsReceived,
    isSaved,
    voteType,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Post) return false;
    final p = props;
    final q = other.props;
    if (p.length != q.length) return false;
    for (var i = 0; i < p.length; i++) {
      final a = p[i];
      final b = q[i];
      if (a is List && b is List) {
        if (!listEquals(a, b)) return false;
      } else if (a != b) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(props);

  /// Returns a copy of this post with the specified fields replaced.
  Post copyWith({
    String? id,
    String? title,
    String? author,
    String? subreddit,
    int? ups,
    int? numComments,
    String? permalink,
    String? content,
    DateTime? createdUtc,
    String? thumbnail,
    String? imageUrl,
    List<String>? images,
    String? url,
    bool? isVideo,
    String? videoUrl,
    bool? isYoutube,
    String? youtubeId,
    double? aspectRatio,
    Post? crosspostParent,
    String? authorFlairText,
    List<FlairItem>? authorFlairRichtext,
    String? linkFlairText,
    List<FlairItem>? linkFlairRichtext,
    int? totalAwardsReceived,
    bool? isSaved,
    bool? isNsfw,
    bool? isStickied,
    VoteType? voteType,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      subreddit: subreddit ?? this.subreddit,
      ups: ups ?? this.ups,
      numComments: numComments ?? this.numComments,
      permalink: permalink ?? this.permalink,
      content: content ?? this.content,
      createdUtc: createdUtc ?? this.createdUtc,
      thumbnail: thumbnail ?? this.thumbnail,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      url: url ?? this.url,
      isVideo: isVideo ?? this.isVideo,
      videoUrl: videoUrl ?? this.videoUrl,
      isYoutube: isYoutube ?? this.isYoutube,
      youtubeId: youtubeId ?? this.youtubeId,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      crosspostParent: crosspostParent ?? this.crosspostParent,
      authorFlairText: authorFlairText ?? this.authorFlairText,
      authorFlairRichtext: authorFlairRichtext ?? this.authorFlairRichtext,
      linkFlairText: linkFlairText ?? this.linkFlairText,
      linkFlairRichtext: linkFlairRichtext ?? this.linkFlairRichtext,
      totalAwardsReceived: totalAwardsReceived ?? this.totalAwardsReceived,
      isSaved: isSaved ?? this.isSaved,
      isNsfw: isNsfw ?? this.isNsfw,
      isStickied: isStickied ?? this.isStickied,
      voteType: voteType ?? this.voteType,
    );
  }
}
