import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yarc/notifiers/theme_notifier.dart';

void main() {
  group('ThemeNotifier', () {
    test('defaults to system theme', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeNotifier();
      await notifier.init();
      expect(notifier.themeMode, ThemeMode.system);
    });

    test('restores saved light mode', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final notifier = ThemeNotifier();
      await notifier.init();
      expect(notifier.themeMode, ThemeMode.light);
    });

    test('restores saved dark mode', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final notifier = ThemeNotifier();
      await notifier.init();
      expect(notifier.themeMode, ThemeMode.dark);
    });

    test('restores saved system mode', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
      final notifier = ThemeNotifier();
      await notifier.init();
      expect(notifier.themeMode, ThemeMode.system);
    });

    test('setThemeMode persists value to prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeNotifier();
      await notifier.init();

      await notifier.setThemeMode(ThemeMode.dark);
      expect(notifier.themeMode, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('setThemeMode is a no-op when mode unchanged', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final notifier = ThemeNotifier();
      await notifier.init();

      var notified = false;
      notifier.addListener(() => notified = true);

      await notifier.setThemeMode(ThemeMode.dark);
      expect(notified, isFalse);
    });
  });
}
