import 'package:flutter/material.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/utils/image_utils.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.subreddits,
    required this.onSubredditSelected,
    required this.onLogout,
    super.key,
    this.currentSubreddit,
  });

  final List<Subreddit> subreddits;
  final String? currentSubreddit;
  final void Function(Subreddit?) onSubredditSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    // Map from DESTINATION index (not child index) to action
    final indexToAction = <int, VoidCallback>{};
    var destinationCount = 0;

    // Helper to add a plain widget
    // (does not count as a destination)
    void addWidget(Widget widget) {
      children.add(widget);
    }

    // Helper to associate a destination widget with an action
    void addDestination(Widget widget, VoidCallback action) {
      children.add(widget);
      indexToAction[destinationCount] = action;
      destinationCount++;
    }

    addDestination(
      const NavigationDrawerDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: Text('Home'),
      ),
      () {
        debugPrint('Selecting Home');
        onSubredditSelected(null);
      },
    );

    addWidget(
      const Padding(
        padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
        child: Divider(),
      ),
    );

    addWidget(
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 10, 16, 10),
        child: Text(
          'Subscriptions',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );

    for (final sub in subreddits) {
      addDestination(
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
        () {
          debugPrint('Selecting Subreddit: ${sub.displayName}');
          onSubredditSelected(sub);
        },
      );
    }

    addWidget(
      const Padding(
        padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
        child: Divider(),
      ),
    );

    // IMPORTANT: Standard ListTiles in the children list of NavigationDrawer
    // generally do NOT count as destinations for selectedIndex logic.
    // We treat Logout as a distinct action (Footer).
    addWidget(
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
    );

    var selectedIndex = 0;

    if (currentSubreddit != null) {
      final subIndex = subreddits.indexWhere(
        (s) => s.displayName == currentSubreddit,
      );
      if (subIndex != -1) {
        // Home is 0. Subreddits start at 1.
        selectedIndex = 1 + subIndex;
      }
    } else {
      selectedIndex = 0;
    }

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        debugPrint('NavigationDrawer destination selection: $index');
        final action = indexToAction[index];
        if (action != null) {
          action();
        } else {
          debugPrint('No action for destination index $index');
        }
      },
      children: children,
    );
  }
}
