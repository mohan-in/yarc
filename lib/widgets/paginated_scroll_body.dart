import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yarc/utils/constants.dart';

/// A reusable scrollable body that wires up pagination and pull-to-refresh.
///
/// Triggers [onLoadMore] when the user scrolls within
/// [kPaginationThreshold] pixels of the bottom. Wraps [slivers] in a
/// [CustomScrollView] inside a [RefreshIndicator].
///
/// This widget replaces the copy-pasted `_scrollListener` pattern that was
/// duplicated across `SavedPostsScreen`, `UserProfileScreen`, etc.
class PaginatedScrollBody extends StatelessWidget {
  const PaginatedScrollBody({
    required this.controller,
    required this.onLoadMore,
    required this.onRefresh,
    required this.slivers,
    super.key,
  });

  final ScrollController controller;

  /// Called when the scroll position is within [kPaginationThreshold] of the
  /// bottom. The callee is responsible for guarding against duplicate calls
  /// (e.g., `FeedNotifier.loadPosts` checks `_isLoading`).
  final VoidCallback onLoadMore;

  final Future<void> Function() onRefresh;
  final List<Widget> slivers;

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) {
      return;
    }
    if (!controller.hasClients) {
      return;
    }
    final position = controller.position;
    if (position.pixels >= position.maxScrollExtent - kPaginationThreshold) {
      onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScrollNotification(notification);
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        displacement: 20,
        child: CustomScrollView(
          controller: controller,
          slivers: slivers,
        ),
      ),
    );
  }
}

/// A small helper that animates the [controller] to the top using the
/// standard [kScrollToTopDuration]. Safe to call even if the controller
/// has no attached clients.
void scrollToTop(ScrollController controller) {
  if (!controller.hasClients) {
    return;
  }
  unawaited(
    controller.animateTo(
      0,
      duration: kScrollToTopDuration,
      curve: Curves.easeOut,
    ),
  );
}
