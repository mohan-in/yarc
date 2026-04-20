import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yarc/models/post.dart';
import 'package:yarc/repositories/post_repository.dart';
import 'package:yarc/screens/post_detail_screen.dart';
import 'package:yarc/screens/settings_screen.dart';
import 'package:yarc/screens/user_profile_screen.dart';

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
    required PostRepository postRepository,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PostDetailScreen(
          post: post,
          postRepository: postRepository,
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
}
