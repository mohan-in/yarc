import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/notifiers/search_notifier.dart';
import 'package:yarc/utils/constants.dart';
import 'package:yarc/utils/image_utils.dart';

/// A SearchDelegate for searching subreddits.
/// Returns the selected subreddit when a result is tapped.
class SubredditSearchDelegate extends SearchDelegate<Subreddit?> {
  SubredditSearchDelegate();

  Timer? _debounceTimer;

  @override
  String get searchFieldLabel => 'Search subreddits';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            _debounceTimer?.cancel();
            context.read<SearchNotifier>().clear();
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        _debounceTimer?.cancel();
        context.read<SearchNotifier>().clear();
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Debounce search to avoid firing a network request on every keystroke
    _debounceTimer?.cancel();
    _debounceTimer = Timer(kSearchDebounceDuration, () {
      if (context.mounted) {
        unawaited(context.read<SearchNotifier>().search(query));
      }
    });

    return _buildSearchResults(context);
  }

  @override
  void close(BuildContext context, Subreddit? result) {
    _debounceTimer?.cancel();
    super.close(context, result);
  }

  Widget _buildSearchResults(BuildContext context) {
    return Consumer<SearchNotifier>(
      builder: (context, searchNotifier, child) {
        if (searchNotifier.query.length < 2) {
          return const Center(
            child: Text('Type at least 2 characters to search'),
          );
        }

        if (searchNotifier.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (searchNotifier.results.isEmpty) {
          return const Center(child: Text('No subreddits found'));
        }

        return ListView.builder(
          itemCount: searchNotifier.results.length,
          itemBuilder: (context, index) {
            final subreddit = searchNotifier.results[index];
            return _SubredditTile(
              subreddit: subreddit,
              onTap: () {
                _debounceTimer?.cancel();
                context.read<SearchNotifier>().clear();
                close(context, subreddit);
              },
            );
          },
        );
      },
    );
  }
}

class _SubredditTile extends StatelessWidget {
  const _SubredditTile({
    required this.subreddit,
    required this.onTap,
  });

  final Subreddit subreddit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      leading: subreddit.iconImg != null
          ? CircleAvatar(
              backgroundImage: NetworkImage(
                ImageUtils.getCorsUrl(subreddit.iconImg!),
              ),
            )
          : const CircleAvatar(child: Icon(Icons.group)),
      title: Text(
        'r/${subreddit.displayName}',
        style: textTheme.bodyLarge?.copyWith(
          fontSize: (textTheme.bodyLarge?.fontSize ?? 16) - 1,
        ),
      ),
      subtitle: subreddit.title.isNotEmpty
          ? Text(
              subreddit.title,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: (textTheme.bodyMedium?.fontSize ?? 14) - 1,
              ),
            )
          : null,
      trailing: subreddit.subscriberCount != null
          ? Text(
              _formatSubscriberCount(subreddit.subscriberCount!),
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  /// Formats the subscriber count in a human-readable way (e.g., 1.2M, 45.3K)
  static String _formatSubscriberCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M members';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K members';
    }
    return '$count members';
  }
}
