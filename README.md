# YARC - Yet Another Reddit Client

A clean and modern Reddit client built with Flutter, designed to provide a seamless browsing experience.

## Features
- **Feed Browsing**: Seamlessly browse your favorite subreddits, custom feeds, and user profiles.
- **Rich Media Support**: Native support for high-quality images, galleries, videos, and YouTube embeds — all cached for fast reloads.
- **Markdown Rendering**: Beautiful rendering of text posts and nested comments with proper formatting and inline images.
- **Search**: Easily discover new communities and users with dual-tab search (subreddits + users).
- **Subreddit Info**: View details, subscriber counts, and descriptions for subreddits with join/leave controls.
- **Authentication**: Secure OAuth2 login to access your personal front page and subscriptions.
- **Deep Linking**: Open Reddit links directly in the app — supports subreddit, post, and user profile links.
- **Read History**: Track which posts you've read, with an option to hide them from the feed.
- **Modern UI**: Polished Material 3 interface with adaptive layouts for phones, foldables, and Samsung DeX.

## Technology Stack
- **Framework**: Flutter & Dart
- **State Management**: Provider
- **Reddit API**: DRAW (Reddit API Wrapper)
- **Local Storage**: Hive (for read history) & SharedPreferences
- **Authentication**: Flutter Web Auth 2
- **Media**: Chewie (Video), YouTube Player Flutter
- **Rendering**: Flutter Markdown Plus, Cached Network Image
- **Utils**: Intl, HTML Unescape

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
Run the app using the following command in your terminal:

```bash
flutter run --dart-define=REDDIT_CLIENT_ID=YOUR_CLIENT_ID
```

Replace `YOUR_CLIENT_ID` with the actual ID you obtained from Reddit.

## Documentation

For detailed architecture and project structure, see [ARCHITECTURE.md](ARCHITECTURE.md).