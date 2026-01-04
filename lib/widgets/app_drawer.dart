import 'package:flutter/material.dart';
import '../models/subreddit.dart';
import '../utils/image_utils.dart';

class AppDrawer extends StatelessWidget {
  final List<Subreddit> subreddits;
  final Function(Subreddit) onSubredditSelected;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.subreddits,
    required this.onSubredditSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Center(
              child: Text(
                'Subscriptions',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: subreddits.isEmpty
                ? const Center(child: Text('No subscriptions found'))
                : ListView.builder(
                    itemCount: subreddits.length,
                    itemBuilder: (context, index) {
                      final sub = subreddits[index];
                      final textTheme = Theme.of(context).textTheme;
                      return ListTile(
                        leading: sub.iconImg != null
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(
                                  ImageUtils.getCorsUrl(sub.iconImg!),
                                ),
                              )
                            : const CircleAvatar(child: Icon(Icons.reddit)),
                        title: Text(
                          sub.displayName,
                          style: textTheme.bodyLarge?.copyWith(
                            fontSize: (textTheme.bodyLarge?.fontSize ?? 16) - 1,
                          ),
                        ),
                        onTap: () {
                          onSubredditSelected(sub);
                          Navigator.pop(context); // Close drawer
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // Close drawer
                onLogout();
              },
            ),
          ),
        ],
      ),
    );
  }
}
