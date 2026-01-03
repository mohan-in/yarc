import 'package:get_it/get_it.dart';
import '../services/auth_service.dart';
import '../services/reddit_service.dart';
import '../services/post_cache_service.dart';

final getIt = GetIt.instance;

/// Registers all services as lazy singletons.
void setupServiceLocator() {
  // Core services
  getIt.registerLazySingleton<AuthService>(() => AuthService());

  // Services with dependencies
  getIt.registerLazySingleton<RedditService>(
    () => RedditService(authService: getIt<AuthService>()),
  );

  getIt.registerLazySingleton<PostCacheService>(() => PostCacheService());
}
