import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/service_locator.dart';
import 'screens/home_screen.dart';
import 'services/post_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  setupServiceLocator();
  await PostCacheService.init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YARC - Yet Another Reddit Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 58), // default 57 + 1
          displayMedium: TextStyle(fontSize: 46), // default 45 + 1
          displaySmall: TextStyle(fontSize: 37), // default 36 + 1
          headlineLarge: TextStyle(fontSize: 33), // default 32 + 1
          headlineMedium: TextStyle(fontSize: 29), // default 28 + 1
          headlineSmall: TextStyle(fontSize: 25), // default 24 + 1
          titleLarge: TextStyle(fontSize: 23), // default 22 + 1
          titleMedium: TextStyle(fontSize: 17), // default 16 + 1
          titleSmall: TextStyle(fontSize: 15), // default 14 + 1
          bodyLarge: TextStyle(fontSize: 17), // default 16 + 1
          bodyMedium: TextStyle(fontSize: 15), // default 14 + 1
          bodySmall: TextStyle(fontSize: 13), // default 12 + 1
          labelLarge: TextStyle(fontSize: 15), // default 14 + 1
          labelMedium: TextStyle(fontSize: 13), // default 12 + 1
          labelSmall: TextStyle(fontSize: 12), // default 11 + 1
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
