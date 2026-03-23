Based on my thorough review of the codebase, here are the most impactful feature improvements organized by category:

## 🔴 High-Impact (Core Reddit Features Missing)

| Feature | Why | Effort |
|---|---|---|
| **Feed Sorting** | No way to sort by Hot/New/Rising/Top/Controversial. A dropdown on the [AppBar](cci:2://file:///home/mohan/Flutter/projects/yarc/lib/screens/home_screen.dart:278:0-321:1) feeding into `FeedNotifier.loadPosts()` — the `draw` API already supports sort params | Low |
| **Time Filters for Top** | When sorting by "Top", users expect Today/Week/Month/Year/All. Pairs naturally with sorting above | Low |
| **Dark Mode** | Only a light theme exists in `theme.dart`. Adding a dark `ThemeData` with a toggle (stored in `SharedPreferences`) is straightforward with Material 3's `ColorScheme.fromSeed(brightness: Brightness.dark)` | Low |

## 🟡 Medium-Impact (Quality of Life)

| Feature | Why | Effort |
|---|---|---|
| **Post Saving / Bookmarks** | Reddit's save API lets users bookmark posts. Could use `draw`'s existing support + a Hive box for offline access | Low |
| **Share Sheet** | A share button on `PostMetadata` using `share_plus` — share post URL via system share sheet | Trivial |
| **User Profile Screen** | Deep links to users are implemented but just load `u_{username}` feed. A proper profile screen showing karma, cake day, and post/comment history would be much better | Medium |
| **Settings Screen** | Currently no settings page. Centralize: dark mode toggle, autoplay on/off, default sort, NSFW filter, image quality preferences | Medium |
| **NSFW Content Filtering** | No filtering exists. Add a setting + filter in [FeedNotifier](cci:2://file:///home/mohan/Flutter/projects/yarc/lib/notifiers/feed_notifier.dart:9:0-211:1) based on `post.over18` | Low |

## 🟢 Polish & Delight

| Feature | Why | Effort |
|---|---|---|
| **Post Flair & User Flair** | Reddit submissions have flair tags — colored labels that categorize posts. Display as chips on [PostCard](cci:2://file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_card.dart:15:0-66:1) | Low |
| **Award Display** | Show gilded/award counts on posts and comments | Low |
| **Pull-to-Refresh Animation** | Current refresh works but a custom animation (Reddit's Snoo, for example) would add personality | Low |
| **Image/Video Download** | Long-press on images/videos to save to gallery using `image_gallery_saver` | Low |

## My Recommended Starting Order

1. **Feed Sorting + Time Filters** — Low effort, huge UX win, foundational for browsing
2. **Dark Mode** — Single most requested feature in any app, trivial with Material 3
3. **Share Sheet** — Trivial to add, expected by every user
4. **Settings Screen** — Needed before adding more toggles

Would you like me to plan and implement any of these?