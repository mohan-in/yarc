import 'dart:async';

import 'package:draw/draw.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthState { loggedIn, loggedOut, unauthenticated }

/// Service responsible for Reddit OAuth2 authentication.
class AuthService {
  static const String _clientId = String.fromEnvironment('REDDIT_CLIENT_ID');
  static const String _userAgent =
      'flutter_reddit_demo/1.0.0 (by /u/antigravity)';
  static const String _credentialsKey = 'reddit_credentials';
  static const List<String> _oauthScopes = [
    'read',
    'identity',
    'mysubreddits',
    'vote',
    'history',
    'subscribe',
  ];

  static const String _redirectUri = 'com.mohan.reddit.client://callback';

  Reddit? _reddit;
  String? _lastSavedCredentials;

  final _authStateController = StreamController<AuthState>.broadcast();

  /// Stream to listen to major authentication state blockages,
  /// like revoked tokens.
  Stream<AuthState> get authStateStream => _authStateController.stream;

  /// Returns the Reddit client instance.
  Reddit? get reddit => _reddit;

  /// Checks if the user is currently logged in.
  /// Returns true if we have valid credentials with a refresh token,
  /// even if the access token has expired.
  /// It will be refreshed automatically.
  bool get isLoggedIn {
    if (_reddit == null) {
      return false;
    }
    try {
      final credentials = _reddit!.auth.credentials;
      return credentials.refreshToken != null;
    } on Exception catch (_) {
      return false;
    }
  }

  /// Persists the current credentials to storage.
  /// Should be called after API operations that may trigger a token refresh.
  /// We intentionally do NOT guard on `auth.isValid` here because the DRAW
  /// library may not reflect the updated state immediately after a refresh.
  Future<void> persistCredentials() async {
    if (_reddit == null) {
      return;
    }

    try {
      final currentCredentials = _reddit!.auth.credentials.toJson();
      if (currentCredentials != _lastSavedCredentials) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_credentialsKey, currentCredentials);
        _lastSavedCredentials = currentCredentials;
      }
    } on Exception catch (_) {}
  }

  /// Initializes the data source, restoring the session if available.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final credentialsJson = prefs.getString(_credentialsKey);

    if (credentialsJson != null) {
      try {
        _reddit = Reddit.restoreAuthenticatedInstance(
          credentialsJson,
          clientId: _clientId,
          userAgent: _userAgent,
          redirectUri: Uri.parse(_redirectUri),
        );
        _lastSavedCredentials = credentialsJson;

        // Check `isLoggedIn` first (has a refresh token) before checking
        // `isValid` (access token not expired). The access token expires every
        // ~1h; an expired access token is NOT a reason to destroy the session.
        if (isLoggedIn) {
          if (!_reddit!.auth.isValid) {
            await refreshSession();
          } else {
            _authStateController.add(AuthState.loggedIn);
          }
        } else {
          _authStateController.add(AuthState.loggedOut);
        }
      } on Exception catch (_) {
        // Do NOT call logout() here. The stored credentials may still be
        // valid. Only emit loggedOut so the UI shows a login prompt without
        // destroying the refresh token — the user can retry without re-auth.
        _authStateController.add(AuthState.loggedOut);
      }
    } else {
      _authStateController.add(AuthState.loggedOut);
    }
  }

  /// Forces a session refresh. Useful when
  /// receiving 401 errors despite the client
  /// thinking the token is valid.
  Future<void> refreshSession() async {
    if (_reddit != null) {
      try {
        await _reddit!.auth.refresh();
        await persistCredentials();
        _authStateController.add(AuthState.loggedIn);
      } on Exception catch (e) {
        debugPrint('Critical refresh failure: $e');
        // Do NOT call logout() here. logout() deletes stored credentials,
        // which would destroy the refresh token on a transient network error.
        // Only emit unauthenticated so the UI can prompt the user, while
        // still keeping the refresh token available for recovery.
        _authStateController.add(AuthState.unauthenticated);
        rethrow;
      }
    }
  }

  /// Initiates the OAuth2 authentication flow.
  /// Returns null on success, or an error message on failure.
  Future<String?> authenticate() async {
    if (_clientId.isEmpty) {
      return 'Reddit Client ID not configured. '
          'Please pass it via '
          '--dart-define=REDDIT_CLIENT_ID=...';
    }

    try {
      final redditConfig = Reddit.createInstalledFlowInstance(
        clientId: _clientId,
        userAgent: _userAgent,
        redirectUri: Uri.parse(_redirectUri),
      );

      final url = redditConfig.auth.url(
        _oauthScopes,
        'random_string',
        compactLogin: true,
      );

      debugPrint('Authenticating with URL: $url');
      debugPrint('Expecting callback at: com.mohan.reddit.client://callback');

      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: 'com.mohan.reddit.client',
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code != null) {
        await _exchangeCodeForToken(code, redditConfig);
        _authStateController.add(AuthState.loggedIn);
        return null; // Success
      } else {
        return 'Login cancelled or no code returned.';
      }
    } on Exception catch (e) {
      return 'Login failed: $e';
    }
  }

  /// Exchanges the authorization code for an access token.
  Future<void> _exchangeCodeForToken(String code, Reddit redditInstance) async {
    try {
      await redditInstance.auth.authorize(code);
      _reddit = redditInstance;

      final credentialsJson = _reddit!.auth.credentials.toJson();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_credentialsKey, credentialsJson);
      _lastSavedCredentials = credentialsJson;
    } on Exception catch (_) {
      rethrow;
    }
  }

  /// Logs out the user by clearing stored credentials.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_credentialsKey);
    _reddit = null;
    _authStateController.add(AuthState.loggedOut);
  }
}
