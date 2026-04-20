import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yarc/models/custom_feed.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/utils/app_router.dart';
import 'package:yarc/utils/image_utils.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.subreddits,
    required this.customFeeds,
    required this.onSubredditSelected,
    required this.onCustomFeedSelected,
    required this.onLogout,
    required this.onSavedSelected,
    super.key,
    this.currentSubreddit,
    this.currentCustomFeedPath,
  });

  final List<Subreddit> subreddits;
  final List<CustomFeed> customFeeds;
  final String? currentSubreddit;
  final String? currentCustomFeedPath;
  final void Function(Subreddit?) onSubredditSelected;
  final void Function(CustomFeed) onCustomFeedSelected;
  final VoidCallback onLogout;
  final VoidCallback onSavedSelected;

  @override
  Widget build(BuildContext context) {
    // Calculate selected index:
    // 0 = Home,
    // 1 to customFeeds.length = Custom Feeds
    // customFeeds.length + 1 to customFeeds.length + subreddits.length
    // = Subreddits
    var selectedIndex = 0;
    if (currentCustomFeedPath != null) {
      final customIndex = customFeeds.indexWhere(
        (f) => f.path == currentCustomFeedPath,
      );
      if (customIndex != -1) {
        selectedIndex = 1 + customIndex;
      }
    } else if (currentSubreddit != null) {
      final subIndex = subreddits.indexWhere(
        (s) => s.displayName == currentSubreddit,
      );
      if (subIndex != -1) {
        selectedIndex = 1 + customFeeds.length + subIndex;
      }
    }

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == 0) {
          onSubredditSelected(null);
        } else if (index <= customFeeds.length) {
          onCustomFeedSelected(customFeeds[index - 1]);
        } else {
          final subIndex = index - customFeeds.length - 1;
          if (subIndex < subreddits.length) {
            onSubredditSelected(subreddits[subIndex]);
          }
        }
      },
      children: [
        // Home destination
        const NavigationDrawerDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),

        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: const Icon(Icons.bookmark_outline),
          title: const Text('Saved'),
          onTap: () {
            Navigator.pop(context);
            onSavedSelected();
          },
        ),

        // Section divider
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
          child: Divider(),
        ),

        if (customFeeds.isNotEmpty) ...[
          // Custom Feeds header
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 10, 16, 10),
            child: Text(
              'Custom Feeds',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),

          // Custom Feed destinations
          for (final feed in customFeeds)
            NavigationDrawerDestination(
              icon: const Icon(Icons.dynamic_feed),
              label: Text(feed.displayName),
            ),

          // Divider between custom feeds and subscriptions
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
            child: Divider(),
          ),
        ],

        // Subscriptions header
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 10, 16, 10),
          child: Text(
            'Subscriptions',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),

        // Subreddit destinations
        for (final sub in subreddits)
          NavigationDrawerDestination(
            icon: sub.iconImg != null
                ? CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(
                      ImageUtils.getCorsUrl(sub.iconImg!),
                    ),
                  )
                : const Icon(Icons.reddit),
            label: Text(sub.displayName),
          ),

        // Footer divider
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
          child: Divider(),
        ),

        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: const Icon(Icons.settings),
          title: const Text('Settings'),
          onTap: () {
            Navigator.pop(context);
            unawaited(AppRouter.toSettings(context));
          },
        ),

        // Logout (not a destination — uses ListTile)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: Icon(
            Icons.logout,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Logout',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () {
            onLogout();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
