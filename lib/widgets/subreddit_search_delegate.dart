import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subreddit.dart';
import '../providers/search_state.dart';
import '../utils/image_utils.dart';

/// A SearchDelegate for searching subreddits.
/// Returns the selected subreddit's display name when a result is tapped.
class SubredditSearchDelegate extends SearchDelegate<String?> {
  final WidgetRef ref;

  SubredditSearchDelegate({required this.ref});

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
            ref.read(searchProvider.notifier).clear();
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        ref.read(searchProvider.notifier).clear();
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
    // Trigger search when user types
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider.notifier).search(query);
    });

    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final searchState = ref.watch(searchProvider);

        if (searchState.query.length < 2) {
          return const Center(
            child: Text('Type at least 2 characters to search'),
          );
        }

        if (searchState.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (searchState.results.isEmpty) {
          return const Center(child: Text('No subreddits found'));
        }

        return ListView.builder(
          itemCount: searchState.results.length,
          itemBuilder: (context, index) {
            final subreddit = searchState.results[index];
            return _buildSubredditTile(context, subreddit);
          },
        );
      },
    );
  }

  Widget _buildSubredditTile(BuildContext context, Subreddit subreddit) {
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
      onTap: () {
        ref.read(searchProvider.notifier).clear();
        close(context, subreddit.displayName);
      },
    );
  }
}
