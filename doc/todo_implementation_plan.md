# Implement All TODO.md Features

Implement all 13 features from [TODO.md](file:///home/mohan/Flutter/projects/yarc/doc/TODO.md) across the YARC Reddit client, following the recommended priority order: Feed Sorting → Dark Mode → Share Sheet → Settings Screen, then remaining features.

## User Review Required

> [!IMPORTANT]
> **Phased Approach**: The plan is structured in 11 phases. Each phase is independently shippable. I recommend implementing them in order since later phases depend on earlier ones (e.g., Settings Screen needs Dark Mode + NSFW toggles to exist first). **Would you like me to implement all 11 phases, or would you prefer to start with a subset?**

> [!WARNING]
> **`draw` Package Sorting API**: The current `RedditService.fetchPosts()` hardcodes `subreddit.hot()`. The `draw` package's `SubredditRef` exposes `.hot()`, `.newest()`, `.top()`, `.rising()`, `.controversial()` methods. Sort + time filter will require switching between these method calls rather than passing params. I'll verify these APIs exist in the installed `draw` version.

> [!IMPORTANT]
> **New Dependencies**: Phases 3 and 11 introduce new packages (`share_plus`, `image_gallery_saver`). Both are widely used and well-maintained. `image_gallery_saver` requires `WRITE_EXTERNAL_STORAGE` permission on Android manifest — I'll handle that.

---

## Proposed Changes

### Phase 1: Feed Sorting + Time Filters

The core sort/time feature touches every layer (Service → Repository → Notifier → UI).

#### [NEW] [feed_sort.dart](file:///home/mohan/Flutter/projects/yarc/lib/models/feed_sort.dart)
- Add `FeedSort` enum: `hot`, `new_`, `rising`, `top`, `controversial`
- Add `TimeFilter` enum: `hour`, `day`, `week`, `month`, `year`, [all](file:///home/mohan/Flutter/projects/yarc/lib/utils/post_parser.dart#349-387)
- Export from [models.dart](file:///home/mohan/Flutter/projects/yarc/lib/models/models.dart) barrel

#### [MODIFY] [reddit_service.dart](file:///home/mohan/Flutter/projects/yarc/lib/services/reddit_service.dart)
- Update [fetchPosts()](file:///home/mohan/Flutter/projects/yarc/lib/services/reddit_service.dart#80-117) to accept `FeedSort sort` and `TimeFilter? timeFilter` params
- Replace the hardcoded `subreddit.hot()` call with a switch on `sort`:
  - `hot` → `.hot()`, `new_` → `.newest()`, `rising` → `.rising()`, `top` → `.top(t: timeFilter)`, `controversial` → `.controversial(t: timeFilter)`
- Same for front page: switch between `reddit.front.best()`, `.hot()`, `.newest()`, etc.

#### [MODIFY] [post_repository.dart](file:///home/mohan/Flutter/projects/yarc/lib/repositories/post_repository.dart)
- Pass through `sort` and `timeFilter` params in [getPosts()](file:///home/mohan/Flutter/projects/yarc/lib/repositories/post_repository.dart#13-19) and [refresh()](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/feed_notifier.dart#107-117)

#### [MODIFY] [feed_notifier.dart](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/feed_notifier.dart)
- Add `_currentSort` (default `FeedSort.hot`) and `_currentTimeFilter` (default `TimeFilter.day`) private fields + getters
- Add `setSort(FeedSort sort)` and `setTimeFilter(TimeFilter filter)` methods that clear posts and reload
- Pass sort/timeFilter through `_repository!.getPosts()` and `_repository!.refresh()`

#### [MODIFY] [home_screen.dart](file:///home/mohan/Flutter/projects/yarc/lib/screens/home_screen.dart)
- Add sort dropdown (`PopupMenuButton<FeedSort>`) to [_AppBarActions](file:///home/mohan/Flutter/projects/yarc/lib/screens/home_screen.dart#279-323)
- Conditionally show time filter dropdown when sort = `top` or `controversial`
- Wire dropdowns → `context.read<FeedNotifier>().setSort()` / `.setTimeFilter()`

---

### Phase 2: Dark Mode

#### [MODIFY] [theme.dart](file:///home/mohan/Flutter/projects/yarc/lib/theme/theme.dart)
- Add `darkAppTheme` using `ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark)`
- Define matching `AppBarTheme`, [CommentTheme](file:///home/mohan/Flutter/projects/yarc/lib/theme/theme.dart#37-69), and [MediaViewerTheme](file:///home/mohan/Flutter/projects/yarc/lib/theme/theme.dart#70-99) for dark mode

#### [NEW] [theme_notifier.dart](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/theme_notifier.dart)
- `ThemeNotifier extends ChangeNotifier` with `ThemeMode _themeMode`
- [init()](file:///home/mohan/Flutter/projects/yarc/lib/main.dart#40-44) loads from `SharedPreferences`
- `toggleTheme()` cycles light ↔ dark and persists
- Export from [notifiers.dart](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/notifiers.dart) barrel

#### [MODIFY] [main.dart](file:///home/mohan/Flutter/projects/yarc/lib/main.dart)
- Register `ChangeNotifierProvider<ThemeNotifier>` in `MultiProvider`
- `MaterialApp`: set `theme: appTheme`, `darkTheme: darkAppTheme`, `themeMode: context.watch<ThemeNotifier>().themeMode`

#### [MODIFY] [app_drawer.dart](file:///home/mohan/Flutter/projects/yarc/lib/widgets/app_drawer.dart)
- Add a dark mode toggle (`SwitchListTile`) at the bottom of the drawer

---

### Phase 3: Share Sheet

#### [MODIFY] [pubspec.yaml](file:///home/mohan/Flutter/projects/yarc/pubspec.yaml)
- Add `share_plus: ^10.0.0`

#### [MODIFY] [post_metadata.dart](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_metadata.dart)
- Add a share `IconButton` next to the copy button
- `onPressed`: call `SharePlus.instance.share(ShareParams(uri: ...))` with the full Reddit URL

---

### Phase 4: NSFW Content Filtering

#### [MODIFY] [post.dart](file:///home/mohan/Flutter/projects/yarc/lib/models/post.dart)
- Add `final bool isNsfw` field (default `false`)

#### [MODIFY] [post_parser.dart](file:///home/mohan/Flutter/projects/yarc/lib/utils/post_parser.dart)
- Parse `submission.over18` → `isNsfw: submission.over18`

#### [MODIFY] [feed_notifier.dart](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/feed_notifier.dart)
- Add `_hideNsfw` field + getter
- Filter in `visiblePosts` getter: if `_hideNsfw`, exclude posts where `isNsfw == true`
- Add `setHideNsfw(bool value)` method

---

### Phase 5: Post Flair & User Flair

#### [MODIFY] [post.dart](file:///home/mohan/Flutter/projects/yarc/lib/models/post.dart)
- Add `linkFlairText`, `linkFlairBackgroundColor`, `authorFlairText` fields

#### [MODIFY] [post_parser.dart](file:///home/mohan/Flutter/projects/yarc/lib/utils/post_parser.dart)
- Parse `link_flair_text`, `link_flair_background_color`, `author_flair_text` from submission data

#### [MODIFY] [post_card.dart](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_card.dart)
- Render flair as a styled `Chip` or `Container` with the flair color after the post title in [_PostHeader](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_card.dart#129-176)

---

### Phase 6: Award Display

#### [MODIFY] [post.dart](file:///home/mohan/Flutter/projects/yarc/lib/models/post.dart)
- Add `final int totalAwardsReceived` field (default `0`)

#### [MODIFY] [post_parser.dart](file:///home/mohan/Flutter/projects/yarc/lib/utils/post_parser.dart)
- Parse `total_awards_received` from submission data

#### [MODIFY] [post_metadata.dart](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_metadata.dart)
- If `totalAwardsReceived > 0`, show award icon + count in the metadata row

---

### Phase 7: Post Saving / Bookmarks

#### [MODIFY] [reddit_service.dart](file:///home/mohan/Flutter/projects/yarc/lib/services/reddit_service.dart)
- Add `savePost(String postId)` and `unsavePost(String postId)` using `draw`'s submission save/unsave API

#### [NEW] [bookmark_service.dart](file:///home/mohan/Flutter/projects/yarc/lib/services/bookmark_service.dart)
- Hive-based local cache of saved post IDs for offline access and fast UI lookups

#### [MODIFY] [post_repository.dart](file:///home/mohan/Flutter/projects/yarc/lib/repositories/post_repository.dart)
- Add `savePost()` / `unsavePost()` / `isSaved()` / `getSavedPostIds()` methods

#### [MODIFY] [feed_notifier.dart](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/feed_notifier.dart)
- Add `_savedPostIds` set, `toggleSave(String postId)` method

#### [MODIFY] [post_metadata.dart](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_metadata.dart)
- Add bookmark toggle button
- Wire to `FeedNotifier.toggleSave()`

#### [MODIFY] [main.dart](file:///home/mohan/Flutter/projects/yarc/lib/main.dart)
- Register `BookmarkService` and update [PostRepository](file:///home/mohan/Flutter/projects/yarc/lib/repositories/post_repository.dart#7-45) dependencies

---

### Phase 8: Settings Screen

#### [NEW] [settings_notifier.dart](file:///home/mohan/Flutter/projects/yarc/lib/notifiers/settings_notifier.dart)
- Manage settings: default sort, NSFW filter toggle, autoplay toggle
- Persist all values via `SharedPreferences`

#### [NEW] [settings_screen.dart](file:///home/mohan/Flutter/projects/yarc/lib/screens/settings_screen.dart)
- `SwitchListTile` for: Dark mode, Hide NSFW, Autoplay videos
- `DropdownButton` for: Default feed sort
- Push from drawer via a "Settings" list tile

#### [MODIFY] [app_drawer.dart](file:///home/mohan/Flutter/projects/yarc/lib/widgets/app_drawer.dart)
- Add "Settings" navigation item

#### [MODIFY] [main.dart](file:///home/mohan/Flutter/projects/yarc/lib/main.dart)
- Register `SettingsNotifier` in `MultiProvider`

---

### Phase 9: User Profile Screen

#### [NEW] [user_profile_screen.dart](file:///home/mohan/Flutter/projects/yarc/lib/screens/user_profile_screen.dart)
- Displays user info (karma, cake day) from `RedditorInfo`
- Shows user's post/comment history using `u_{username}` feed
- Navigate here when tapping `u/author` in [_PostHeader](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_card.dart#129-176) instead of loading `u_{username}` feed inline

#### [MODIFY] [post_card.dart](file:///home/mohan/Flutter/projects/yarc/lib/widgets/post_card.dart)
- Make `u/author` text tappable → navigates to `UserProfileScreen`

---

### Phase 10: Pull-to-Refresh Animation

#### [MODIFY] [home_screen.dart](file:///home/mohan/Flutter/projects/yarc/lib/screens/home_screen.dart)
- Customize `RefreshIndicator` with themed colors and optionally a branded displacement/stroke animation

---

### Phase 11: Image/Video Download

#### [MODIFY] [pubspec.yaml](file:///home/mohan/Flutter/projects/yarc/pubspec.yaml)
- Add `image_gallery_saver: ^2.0.3`

#### [MODIFY] [AndroidManifest.xml](file:///home/mohan/Flutter/projects/yarc/android/app/src/main/AndroidManifest.xml)
- Add `WRITE_EXTERNAL_STORAGE` permission (for Android < 10, scoped storage handles it on newer)

#### [MODIFY] [full_screen_image_view.dart](file:///home/mohan/Flutter/projects/yarc/lib/widgets/full_screen_image_view.dart)
- Add a download button (FAB or app bar action)
- On tap: download image bytes → `ImageGallerySaver.saveImage()`

---

## Verification Plan

### Automated Tests

**Command to run all existing tests:**
```bash
cd /home/mohan/Flutter/projects/yarc && flutter test
```

**Existing tests** (2 widget tests in `test/widgets/`):
- `post_card_test.dart` — verifies `PostCard` renders title/content with correct theme font sizes. **Will need updates** when new fields (`isNsfw`, flair, awards) are added to the `Post` constructor.
- `comment_tile_test.dart` — verifies `CommentTile` renders with theme. Unaffected by these changes.

**New tests to write:**

1. **`test/notifiers/feed_notifier_test.dart`** — Unit test for:
   - `setSort()` clears posts and triggers load
   - `setTimeFilter()` clears posts and triggers load
   - `visiblePosts` filters NSFW posts when `hideNsfw` is true
   - `toggleSave()` adds/removes post IDs from saved set

2. **`test/notifiers/theme_notifier_test.dart`** — Unit test for:
   - `toggleTheme()` switches between light and dark
   - Theme mode persists via SharedPreferences (mock)

3. **Update `test/widgets/post_card_test.dart`** — Update the `Post` constructor call to include new required fields.

### Manual Verification

> [!NOTE]
> Since these features are primarily UI-driven (dropdowns, theme toggles, share sheets), manual testing on an Android device or emulator is essential for validating the user experience.

**Suggested manual test steps** (I'd appreciate your input on which device/emulator to target):

1. **Feed Sorting**: Open the app → tap sort dropdown in AppBar → select "Top" → verify time filter appears → select "Week" → verify feed reloads with top weekly posts
2. **Dark Mode**: Open drawer → toggle dark mode switch → verify all screens use dark colors → kill and reopen the app → verify mode persists
3. **Share Sheet**: Long-press or tap share icon on a post → verify system share sheet opens with correct Reddit URL
4. **NSFW Filter**: Navigate to a subreddit known to have NSFW posts → enable NSFW filter in settings → verify NSFW posts are hidden
5. **Flair Display**: Browse a subreddit with post flairs (e.g., r/android) → verify colored flair chips appear on relevant posts

### Static Analysis

```bash
cd /home/mohan/Flutter/projects/yarc && flutter analyze
```

Must produce **zero errors** before marking any phase complete.
