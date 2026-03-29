import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/models/feed_sort.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/notifiers/theme_notifier.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer2<SettingsNotifier, ThemeNotifier>(
        builder: (context, settings, theme, _) {
          return ListView(
            children: [
              ListTile(
                title: const Text('Theme'),
                subtitle: const Text('Choose light, dark, or follow system'),
                trailing: SegmentedButton<ThemeMode>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      tooltip: 'Light',
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      tooltip: 'System',
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      tooltip: 'Dark',
                    ),
                  ],
                  selected: {theme.themeMode},
                  onSelectionChanged: (modes) =>
                      unawaited(theme.setThemeMode(modes.first)),
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Default Feed Sort'),
                subtitle: const Text(
                  'The default sort order for subreddit feeds',
                ),
                trailing: DropdownButton<FeedSort>(
                  value: settings.defaultSort,
                  onChanged: (sort) {
                    if (sort != null) {
                      unawaited(settings.setDefaultSort(sort));
                    }
                  },
                  items: FeedSort.values.map((sort) {
                    return DropdownMenuItem<FeedSort>(
                      value: sort,
                      child: Text(feedSortLabel(sort)),
                    );
                  }).toList(),
                ),
              ),
              SwitchListTile(
                title: const Text('Hide NSFW'),
                subtitle: const Text('Filter out NSFW content from feeds'),
                value: settings.hideNsfw,
                onChanged: (v) => unawaited(settings.setHideNsfw(v)),
              ),
              SwitchListTile(
                title: const Text('Auto-play Videos'),
                subtitle: const Text('Play videos automatically in the feed'),
                value: settings.autoPlayVideos,
                onChanged: (v) => unawaited(settings.setAutoPlayVideos(v)),
              ),
              SwitchListTile(
                title: const Text('Mute Videos by Default'),
                subtitle: const Text('Start auto-playing videos muted'),
                value: settings.muteVideosByDefault,
                onChanged: (v) => unawaited(settings.setMuteVideosByDefault(v)),
              ),
              SwitchListTile(
                title: const Text('Use System Browser'),
                subtitle: const Text(
                  'Open links in the system browser instead of in-app WebView',
                ),
                value: settings.useSystemBrowser,
                onChanged: (v) => unawaited(settings.setUseSystemBrowser(v)),
              ),
              SwitchListTile(
                title: const Text('Hide Read Posts'),
                subtitle: const Text(
                  'Automatically hide posts you have scrolled past or clicked',
                ),
                value: settings.hideReadPosts,
                onChanged: (v) => unawaited(settings.setHideReadPosts(v)),
              ),
            ],
          );
        },
      ),
    );
  }
}
