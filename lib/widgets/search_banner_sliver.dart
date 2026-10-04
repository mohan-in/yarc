import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/notifiers/feed_notifier.dart';

/// A sliver banner displaying the active search query in a subreddit feed,
/// with an action to clear the search.
class SearchBannerSliver extends StatelessWidget {
  const SearchBannerSliver({super.key});

  @override
  Widget build(BuildContext context) {
    final searchQuery = context.select<FeedNotifier, String?>(
      (n) => n.searchQuery,
    );

    if (searchQuery == null) {
      return const SliverToBoxAdapter(
        child: SizedBox.shrink(),
      );
    }

    return SliverToBoxAdapter(
      child: Material(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Results for "$searchQuery"',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear search',
                onPressed: () {
                  unawaited(
                    context.read<FeedNotifier>().clearSubredditSearch(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
