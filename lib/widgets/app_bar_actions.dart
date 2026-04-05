import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/notifiers/notifiers.dart';
import 'package:yarc/widgets/sort_filter_bottom_sheet.dart';

/// A reusable set of AppBar actions (Sort, Search, Hide Read) used across
/// the Home, User Profile, and Saved Posts screens.
class UniversalAppBarActions extends StatelessWidget {
  const UniversalAppBarActions({
    required this.onScrollToTop,
    this.onSearch,
    this.showSort = true,
    this.showSearch = true,
    super.key,
  });

  final VoidCallback onScrollToTop;

  /// Optional search callback. If null, the search icon is hidden.
  final VoidCallback? onSearch;

  /// Whether to show the Sort icon.
  final bool showSort;

  /// Whether to show the Search icon.
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    // We listen to the feed state for the "Hide Read" toggle and sort logic.
    final hideRead = context.select<FeedNotifier, bool>((n) => n.hideRead);
    final isLoggedIn = context.select<AuthNotifier, bool>((n) => n.isLoggedIn);

    final hasSubreddit = context.select<FeedNotifier, String?>(
          (n) => n.currentSubreddit,
        ) !=
        null;

    // Only show actions if logged in or viewing a specific subreddit.
    final hasContext = isLoggedIn || hasSubreddit;

    if (!hasContext) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSort)
          IconButton(
            tooltip: 'Sort Posts',
            icon: const Icon(Icons.sort),
            onPressed: () {
              SortFilterBottomSheet.show(
                context,
                onSortApplied: onScrollToTop,
              );
            },
          ),
        if (showSearch && onSearch != null)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: onSearch,
            tooltip: 'Search',
          ),
        IconButton(
          icon: Icon(
            hideRead ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            unawaited(context.read<FeedNotifier>().toggleHideRead());
            onScrollToTop();
          },
          tooltip: hideRead ? 'Show All Posts' : 'Hide Read Posts',
        ),
      ],
    );
  }
}
