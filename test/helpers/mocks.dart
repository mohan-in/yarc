import 'package:mocktail/mocktail.dart';
import 'package:yarc/notifiers/settings_notifier.dart';
import 'package:yarc/repositories/biometric_repository.dart';
import 'package:yarc/repositories/post_repository.dart';
import 'package:yarc/repositories/subreddit_repository.dart';

class MockBiometricRepository extends Mock implements BiometricRepository {}

class MockPostRepository extends Mock implements PostRepository {}

class MockSettingsNotifier extends Mock implements SettingsNotifier {}

class MockSubredditRepository extends Mock implements SubredditRepository {}
