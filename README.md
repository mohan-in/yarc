# YARC - Yet Another Reddit Client

A clean and modern Reddit client built with Flutter, designed to provide a seamless browsing experience.

## Features

- **Feed Browsing**: Seamlessly browse your favourite subreddits, custom feeds, and user profiles.
- **Rich Media Support**: Native support for high-quality images, galleries, videos, and YouTube embeds — all cached for fast reloads.
- **Markdown Rendering**: Beautiful rendering of text posts and nested comments with proper formatting, inline images, and Giphy GIFs.
- **Sort & Filter**: Change feed sort order (Best, Hot, New, Top, Controversial, Rising) from any screen. Time-range filters are shown automatically when relevant.
- **Search**: Discover new communities and users with a dual-tab search (subreddits + users).
- **Subreddit Info**: View descriptions, subscriber counts, and join/leave controls for any subreddit.
- **User Profiles**: Browse any user's post history, karma, and account info.
- **Saved Posts**: View and manage your Reddit-saved posts, with the same sort and hide-read controls as the main feed.
- **Authentication**: Secure OAuth2 login to access your personal front page and subscriptions.
- **Deep Linking**: Open Reddit links directly in the app — supports subreddit, post, and user profile links.
- **Read History**: Track which posts you've read, with an option to hide them from the feed across all screens.
- **Flair Rendering**: Rich flair display with custom subreddit emojis, HTML-entity decoding, and graceful fallback to plain text.
- **NSFW Filter**: Optionally hide NSFW posts from the feed. Logged-out users see a content warning indicator on flagged posts.
- **Settings**: Persistent per-user settings (auto-play, mute, browser choice, hide-read default, NSFW filter, default sort) stored via `SharedPreferences`.
- **Theme**: Light, dark, and system-default theme modes, selectable from Settings.
- **Modern UI**: Polished Material 3 interface with adaptive layouts for phones, foldables, and Samsung DeX (master-detail two-pane layout on wide screens).

## Technology Stack

- **Framework**: Flutter & Dart
- **State Management**: Provider (ChangeNotifier)
- **Reddit API**: DRAW (Reddit API Wrapper)
- **Local Storage**: Hive (read history) & SharedPreferences (settings + theme)
- **Authentication**: Flutter Web Auth 2
- **Media**: Chewie (video), YouTube Player Flutter
- **Rendering**: Flutter Markdown Plus, Cached Network Image
- **Utils**: Intl, HTML Unescape, App Links (deep linking), Visibility Detector (autoplay)

## Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable channel recommended)
- [Dart SDK](https://dart.dev/get-dart)
- An IDE (VS Code, Android Studio, or IntelliJ) with Flutter plugins installed.
- A Reddit account to generate an API Client ID.

## Getting Started

To run this app, you need a Reddit API Client ID to access Reddit's data.

### 1. Generate Reddit Client ID

1. Log in to your Reddit account.
2. Go to [Reddit App Preferences](https://www.reddit.com/prefs/apps/).
3. Click **"create another app..."** (or "create app" if it's your first one).
4. Fill in the details:
   - **Name**: `YARC` (or anything you like)
   - **App type**: Select **"installed app"**.
   - **Description**: (Optional)
   - **About url**: (Optional)
   - **Redirect uri**: `com.mohan.reddit.client://callback` (**Crucial**: This must match exactly!)
5. Click **"create app"**.
6. Copy the string listed just under your app name. This is your **Client ID**.

### 2. Run the App

```bash
flutter run --dart-define=REDDIT_CLIENT_ID=YOUR_CLIENT_ID
```

Replace `YOUR_CLIENT_ID` with the actual ID you obtained from Reddit.

## Documentation

For detailed architecture and project structure, see [ARCHITECTURE.md](doc/ARCHITECTURE.md).