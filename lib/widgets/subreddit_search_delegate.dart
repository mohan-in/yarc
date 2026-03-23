import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/models.dart';
import 'package:yarc/notifiers/search_notifier.dart';
import 'package:yarc/utils/constants.dart';
import 'package:yarc/utils/image_utils.dart';
import 'package:yarc/utils/number_format_utils.dart';

/// A SearchDelegate for searching subreddits and users.
/// Returns a [SearchResult] when a result is tapped.
class SubredditSearchDelegate extends SearchDelegate<SearchResult?> {
  SubredditSearchDelegate();

  Timer? _debounceTimer;

  @override
  String get searchFieldLabel => 'Search subreddits or users';

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
    return _SearchBody(
      query: query,
      debounceTimer: _debounceTimer,
      onDebounce: (timer) => _debounceTimer = timer,
      onSelectSubreddit: (sub) {
        _debounceTimer?.cancel();
        context.read<SearchNotifier>().clear();
        close(context, SearchResult(subreddit: sub));
      },
      onSelectUser: (username) {
        _debounceTimer?.cancel();
        context.read<SearchNotifier>().clear();
        close(context, SearchResult(username: username));
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _SearchBody(
      query: query,
      debounceTimer: _debounceTimer,
      onDebounce: (timer) => _debounceTimer = timer,
      onSelectSubreddit: (sub) {
        _debounceTimer?.cancel();
        context.read<SearchNotifier>().clear();
        close(context, SearchResult(subreddit: sub));
      },
      onSelectUser: (username) {
        _debounceTimer?.cancel();
        context.read<SearchNotifier>().clear();
        close(context, SearchResult(username: username));
      },
    );
  }

  @override
  void close(BuildContext context, SearchResult? result) {
    _debounceTimer?.cancel();
    super.close(context, result);
  }
}

/// The body of the search — a TabBar with Subreddits and Users tabs.
class _SearchBody extends StatefulWidget {
  const _SearchBody({
    required this.query,
    required this.debounceTimer,
    required this.onDebounce,
    required this.onSelectSubreddit,
    required this.onSelectUser,
  });

  final String query;
  final Timer? debounceTimer;
  final ValueChanged<Timer> onDebounce;
  final ValueChanged<Subreddit> onSelectSubreddit;
  final ValueChanged<String> onSelectUser;

  @override
  State<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<_SearchBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SearchBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _lastQuery) {
      _lastQuery = widget.query;
      _triggerSearch();
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _triggerSearch();
    }
  }

  void _triggerSearch() {
    widget.debounceTimer?.cancel();
    final timer = Timer(kSearchDebounceDuration, () {
      if (mounted) {
        final notifier = context.read<SearchNotifier>();
        if (_tabController.index == 0) {
          unawaited(notifier.search(widget.query));
        } else {
          unawaited(notifier.searchUser(widget.query));
        }
      }
    });
    widget.onDebounce(timer);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Subreddits'),
            Tab(text: 'Users'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _SubredditResults(onSelect: widget.onSelectSubreddit),
              _UserResults(onSelect: widget.onSelectUser),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Subreddit results tab
// ---------------------------------------------------------------------------

class _SubredditResults extends StatelessWidget {
  const _SubredditResults({required this.onSelect});

  final ValueChanged<Subreddit> onSelect;

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchNotifier>(
      builder: (context, notifier, _) {
        if (notifier.query.length < 2) {
          return const Center(
            child: Text('Type at least 2 characters to search'),
          );
        }

        if (notifier.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (notifier.results.isEmpty) {
          return const Center(child: Text('No subreddits found'));
        }

        return ListView.builder(
          itemCount: notifier.results.length,
          itemBuilder: (context, index) {
            final subreddit = notifier.results[index];
            return _SubredditTile(
              subreddit: subreddit,
              onTap: () => onSelect(subreddit),
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

  static String _formatSubscriberCount(int count) {
    return NumberFormatUtils.formatCompact(count, suffix: ' members');
  }
}

// ---------------------------------------------------------------------------
// User results tab
// ---------------------------------------------------------------------------

class _UserResults extends StatelessWidget {
  const _UserResults({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchNotifier>(
      builder: (context, notifier, _) {
        if (notifier.isUserLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!notifier.userSearched) {
          return const Center(
            child: Text('Type a username to look up'),
          );
        }

        final user = notifier.userResult;
        if (user == null) {
          return const Center(child: Text('User not found'));
        }

        return ListView(
          children: [_UserTile(user: user, onTap: () => onSelect(user.name))],
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onTap,
  });

  final RedditorInfo user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.person,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        'u/${user.name}',
        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${_formatKarma(user.totalKarma)} karma'
        '${user.createdUtc != null ? '\nJoined '
                  '${_formatAge(user.createdUtc!)}' : ''}',
        style: textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  static String _formatKarma(int karma) {
    return NumberFormatUtils.formatCompact(karma);
  }

  static String _formatAge(DateTime created) {
    final age = DateTime.now().difference(created);
    if (age.inDays >= 365) {
      final years = age.inDays ~/ 365;
      return '${years}y old';
    } else if (age.inDays >= 30) {
      final months = age.inDays ~/ 30;
      return '${months}mo old';
    }
    return '${age.inDays}d old';
  }
}
