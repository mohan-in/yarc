import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yarc/models/subreddit.dart';
import 'package:yarc/screens/settings_screen.dart';
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
    // Calculate selected index: 0 = Home, 1+ = subreddits
    var selectedIndex = 0;
    if (currentSubreddit != null) {
      final subIndex = subreddits.indexWhere(
        (s) => s.displayName == currentSubreddit,
      );
      if (subIndex != -1) {
        selectedIndex = 1 + subIndex;
      }
    }

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == 0) {
          onSubredditSelected(null);
        } else {
          final subIndex = index - 1;
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

        // Section divider
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
          child: Divider(),
        ),

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
            unawaited(
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const SettingsScreen(),
                ),
              ),
            );
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
