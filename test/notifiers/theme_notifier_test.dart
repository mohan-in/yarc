import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yarc/notifiers/theme_notifier.dart';

void main() {
  group('ThemeNotifier', () {
    test('initializes with dark mode false by default', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeNotifier();
      // Allow async init to complete
      await Future<void>.delayed(Duration.zero);
      expect(notifier.isDarkMode, false);
    });

    test('initializes with saved value', () async {
      SharedPreferences.setMockInitialValues({'darkMode': true});
      final notifier = ThemeNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.isDarkMode, true);
    });

    test('toggleTheme updates value and saves to prefs', () async {
      SharedPreferences.setMockInitialValues({'darkMode': false});
      final notifier = ThemeNotifier();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.isDarkMode, false);

      await notifier.toggleTheme();
      expect(notifier.isDarkMode, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('darkMode'), true);
    });
  });
}
