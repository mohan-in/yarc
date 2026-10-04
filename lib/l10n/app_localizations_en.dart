// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'YARC';

  @override
  String get home => 'Home';

  @override
  String get saved => 'Saved';

  @override
  String get settings => 'Settings';

  @override
  String get search => 'Search';

  @override
  String get upvote => 'Upvote';

  @override
  String get downvote => 'Downvote';

  @override
  String get share => 'Share';

  @override
  String get save => 'Save';

  @override
  String get unsave => 'Unsave';

  @override
  String get comments => 'Comments';

  @override
  String get offlineModeBanner => 'Offline mode — showing cached posts';

  @override
  String get selectPostToRead => 'Select a post to read';

  @override
  String get biometricReason => 'Authenticate to view NSFW content';

  @override
  String get login => 'Log In';

  @override
  String get logout => 'Log Out';
}
