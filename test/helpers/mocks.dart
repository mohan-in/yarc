import 'package:draw/draw.dart' as draw;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yarc/notifiers/auth_notifier.dart';
import 'package:yarc/notifiers/comments_notifier.dart';
import 'package:yarc/notifiers/feed_notifier.dart';
import 'package:yarc/notifiers/search_notifier.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/notifiers/subreddits_notifier.dart';
import 'package:yarc/notifiers/user_notifier.dart';
import 'package:yarc/notifiers/video_autoplay_notifier.dart';
import 'package:yarc/repositories/auth_repository.dart';
import 'package:yarc/repositories/biometric_repository.dart';
import 'package:yarc/repositories/post_repository.dart';
import 'package:yarc/repositories/subreddit_repository.dart';
import 'package:yarc/repositories/user_repository.dart';
import 'package:yarc/services/auth_service.dart';
import 'package:yarc/services/feed_cache_service.dart';
import 'package:yarc/services/history_service.dart';
import 'package:yarc/services/reddit_service.dart';

class MockAuthNotifier extends Mock implements AuthNotifier {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthService extends Mock implements AuthService {}

class MockBiometricRepository extends Mock implements BiometricRepository {}

class MockBox<T> extends Mock implements Box<T> {}

class MockComment extends Mock implements draw.Comment {}

class MockCommentsNotifier extends Mock implements CommentsNotifier {}

class MockFeedCacheService extends Mock implements FeedCacheService {}

class MockFeedNotifier extends Mock implements FeedNotifier {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockHistoryService extends Mock implements HistoryService {}

class MockPostRepository extends Mock implements PostRepository {}

class MockReddit extends Mock implements draw.Reddit {}

class MockRedditService extends Mock implements RedditService {}

class MockSearchNotifier extends Mock implements SearchNotifier {}

class MockSettingsNotifier extends Mock implements SettingsNotifier {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockSubmission extends Mock implements draw.Submission {}

class MockSubredditRepository extends Mock implements SubredditRepository {}

class MockSubredditsNotifier extends Mock implements SubredditsNotifier {}

class MockUserNotifier extends Mock implements UserNotifier {}

class MockUserRepository extends Mock implements UserRepository {}

class MockVideoAutoplayNotifier extends Mock implements VideoAutoplayNotifier {}
