# Implement All TODO.md Features

## Phase 1: Feed Sorting + Time Filters (High-Impact, Low Effort)
- [x] Add `FeedSort` enum and [TimeFilter](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/feed_notifier.dart#80-92) enum to `models/`
- [x] Update `RedditService.fetchPosts()` to accept sort + time filter params
- [x] Update `PostRepository.getPosts()` / [refresh()](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/feed_notifier.dart#148-158) signatures
- [x] Add sort/time state to [FeedNotifier](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/feed_notifier.dart#12-309), expose getters + setters
- [x] Add sort dropdown + time filter UI to [_AppBarActions](file:///home/mohan/Flutter/projects/yarc/lib/screens/home_screen.dart#281-398) in [home_screen.dart](file:///home/mohan/Flutter/projects/yarc/lib/screens/home_screen.dart)
- [x] Wire up UI → notifier → repo → service

## Phase 2: Dark Mode (High-Impact, Low Effort)
- [x] Add dark `ThemeData` to [theme.dart](file:///home/mohan/Flutter/projects/yarc/lib/theme/theme.dart) using `ColorScheme.fromSeed(brightness: Brightness.dark)`
- [x] Create [ThemeNotifier](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/theme_notifier.dart#5-36) to hold light/dark mode state (with `SharedPreferences` persistence)
- [x] Initialize [ThemeNotifier](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/theme_notifier.dart#5-36) in [main.dart](file:///home/mohan/Flutter/projects/yarc/lib/main.dart) and pass it to `MaterialApp.themeMode`
- [x] Add a Dark Mode toggle to the `Drawer` in [home_screen.dart](file:///home/mohan/Flutter/projects/yarc/lib/screens/home_screen.dart)
- [ ] Add toggle to app drawer or settings (once settings exists)

## Phase 3: Share Sheet (Trivial)
- [x] Run `flutter pub add share_plus`
- [x] In [post_metadata.dart](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_metadata.dart), replace `Clipboard.setData(...)` logic with `Share.share(postUrl)` on the copy button (and change icon to `Icons.share`) full Reddit URL via system share sheet

## Phase 4: NSFW Content Filtering (Medium-Impact, Low Effort)
- [x] Add `over18` field to [Post](file:///home/mohan/Flutter/projects/yarc/lib/models/post.dart#4-135) model
- [x] Parse `over18` from `draw.Submission` in [PostParser](file:///home/mohan/Flutter/projects/yarc/lib/utils/post_parser.dart#6-494)
- [x] Update [FeedNotifier](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/feed_notifier.dart#12-309) to filter out posts where `over18 == true` (SharedPreferences via a notifier)
- [ ] Filter in `FeedNotifier.visiblePosts` when enabled

## Phase 5: Post Flair & User Flair (Polish, Low Effort)
- [x] Update [Post](file:///home/mohan/Flutter/projects/yarc/lib/models/post.dart#4-135) model with `linkFlairText` and `authorFlairText`
- [x] Parse from `draw.Submission`
- [x] Render small chips/badges in [PostCard](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_card.dart#16-63) (e.g., next to author name and above post title)

## Phase 6: Award Display (Polish, Low Effort)
- [x] Add `totalAwardsReceived` (or award list) to [Post](file:///home/mohan/Flutter/projects/yarc/lib/models/post.dart#4-135) model
- [x] Extract `total_awards_received` from `draw.Submission`
- [x] Render a small icon and award count in [PostCard](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_card.dart#16-63) (e.g., next to or below the subreddit name)

## Phase 7: Post Saving / Bookmarks (Medium-Impact, Low Effort)
- [x] Add save/unsave methods to [RedditService](file:///home/mohan/Flutter/projects/yarc/lib/services/reddit_service.dart#15-374) (Reddit API)
- [x] Add `isSaved` field to [Post](file:///home/mohan/Flutter/projects/yarc/lib/models/post.dart#4-135)
- [x] Render action button (Save/Unsave) on [PostMetadata](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_metadata.dart#12-73) footer
- [x] Add save button to [PostMetadata](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_metadata.dart#12-73), toggle state
- [x] (Optional) Add "Saved" feed to drawer

## Phase 8: Settings Screen (Medium-Impact, Medium Effort)
- [x] Create `SettingsNotifier` (ChangeNotifier) managing all settings in SharedPreferences
- [x] Create `screens/settings_screen.dart` with toggles: dark mode, NSFW filter, default sort, autoplay
- [x] Add Settings entry in app drawer
- [x] Wire settings into existing notifiers

## Phase 9: User Profile Screen (Medium-Impact, Medium Effort)
- [x] Create `screens/user_profile_screen.dart`
- [x] Show karma, cake day, post/comment history
- [x] Navigate to profile from user tap in [_PostHeader](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_card.dart#124-218)

## Phase 10: Pull-to-Refresh Animation (Polish, Low Effort)
- [x] Implement custom `RefreshIndicator` with themed animation

## Phase 11: Image/Video Download (Polish, Low Effort)
- [x] Add `image_gallery_saver` dependency
- [x] Add long-press handler on `CachedImage` / `FullScreenImageView` to save to gallery

## Verification
- [x] Run `flutter analyze` — zero errors
- [ ] Run existing widget tests — all pass
- [ ] Add unit tests for [FeedNotifier](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/feed_notifier.dart#12-309) sort/filter logic
- [ ] Add unit test for [ThemeNotifier](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/theme_notifier.dart#5-36) persistence
- [ ] Manual testing on Android device/emulator
