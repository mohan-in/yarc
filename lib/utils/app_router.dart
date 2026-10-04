import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/screens/post_detail_screen.dart';
import 'package:yarc/screens/saved_posts_screen.dart';
import 'package:yarc/screens/settings_screen.dart';
import 'package:yarc/screens/subreddit_feed_screen.dart';
import 'package:yarc/screens/top_subreddits_screen.dart';
import 'package:yarc/screens/user_profile_screen.dart';
import 'package:yarc/widgets/full_screen_image_view.dart';

/// Centralised navigation helper.
///
/// Using static methods here avoids scattering `MaterialPageRoute`
/// construction throughout the widget tree. Switching to a declarative
/// router (e.g. go_router) in the future only requires changes here.
abstract final class AppRouter {
  /// Navigates to the [PostDetailScreen] for [post].
  static Future<void> toPostDetail(
    BuildContext context, {
    required Post post,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(
          post: post,
        ),
      ),
    );
  }

  /// Navigates to the [UserProfileScreen] for [username].
  static Future<void> toUserProfile(
    BuildContext context,
    String username,
  ) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(username: username),
      ),
    );
  }

  /// Navigates to the [SettingsScreen].
  static Future<void> toSettings(BuildContext context) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  /// Navigates to the [TopSubredditsScreen].
  static Future<void> toTopSubreddits(BuildContext context) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const TopSubredditsScreen(),
      ),
    );
  }

  /// Navigates to the [SubredditFeedScreen] for [subreddit].
  ///
  /// Uses a scoped feed notifier so the global home-screen feed is untouched.
  /// The back button returns to the previous screen (e.g. Popular Subreddits).
  static Future<void> toSubredditFeed(
    BuildContext context, {
    required Subreddit subreddit,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SubredditFeedScreen(subreddit: subreddit),
      ),
    );
  }

  /// Navigates to a [SubredditFeedScreen] using only the subreddit [name].
  ///
  /// Use when only a name string is available (e.g. tapping the subreddit
  /// label on a post card). Subreddit metadata is fetched lazily.
  static Future<void> toSubredditFeedByName(
    BuildContext context, {
    required String name,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SubredditFeedScreen.fromName(name: name),
      ),
    );
  }

  /// Navigates to the [SavedPostsScreen] for [username].
  static Future<void> toSavedPosts(
    BuildContext context, {
    required String username,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SavedPostsScreen(username: username),
      ),
    );
  }

  /// Navigates to the [FullScreenImageView].
  static Future<void> toFullScreenImageView(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FullScreenImageView(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}
