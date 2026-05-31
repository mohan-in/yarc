import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:draw/draw.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yarc/utils/constants.dart';

enum AuthState { loggedIn, loggedOut, unauthenticated }

/// Service responsible for Reddit OAuth2 authentication.
class AuthService {
  AuthService(this._prefs);

  static const String _clientId = String.fromEnvironment('REDDIT_CLIENT_ID');
  static const String _credentialsKey = 'reddit_credentials';
  static const List<String> _oauthScopes = [
    'read',
    'identity',
    'mysubreddits',
    'vote',
    'history',
    'subscribe',
    'save',
    'submit',
    'edit',
  ];

  static const String _redirectUri = 'com.mohan.reddit.client://callback';

  final SharedPreferences _prefs;

  Reddit? _reddit;
  String? _lastSavedCredentials;
  String? _currentUsername;

  /// Holds the CSRF state token generated for the in-flight OAuth request.
  /// Cleared after the callback is received (whether successful or not).
  String? _pendingOAuthState;

  final _authStateController = StreamController<AuthState>.broadcast();

  /// Stream to listen to major authentication state blockages,
  /// like revoked tokens.
  Stream<AuthState> get authStateStream => _authStateController.stream;

  /// Returns the Reddit client instance.
  Reddit? get reddit => _reddit;

  /// Returns the currently logged in username.
  String? get currentUsername => _currentUsername;

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
        await _prefs.setString(_credentialsKey, currentCredentials);
        _lastSavedCredentials = currentCredentials;
      }
    } on Exception catch (_) {}
  }

  /// Initializes the data source, restoring the session if available.
  Future<void> init() async {
    final credentialsJson = _prefs.getString(_credentialsKey);

    if (credentialsJson != null) {
      if (_clientId.isEmpty) {
        developer.log(
          'Client ID missing. Cannot restore session.',
          name: 'AuthService',
        );
        _authStateController.add(AuthState.loggedOut);
        return;
      }

      try {
        _reddit = Reddit.restoreInstalledAuthenticatedInstance(
          credentialsJson,
          clientId: _clientId,
          userAgent: kUserAgent,
          redirectUri: Uri.parse(_redirectUri),
        );
        _lastSavedCredentials = credentialsJson;

        // Check `isLoggedIn` first (has a refresh token) before checking
        // `isValid` (access token not expired). The access token expires every
        // ~1h; an expired access token is NOT a reason to destroy the session.
        if (isLoggedIn) {
          _currentUsername = (await _reddit!.user.me())?.displayName;
          if (!_reddit!.auth.isValid) {
            try {
              await refreshSession();
            } on Exception catch (_) {
              // Transient network error on startup. Emit loggedIn anyway —
              // the DRAW library will auto-refresh on the next API call
              // when connectivity is restored.
              _authStateController.add(AuthState.loggedIn);
            }
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
        developer.log(
          'Refresh failure: $e',
          name: 'AuthService',
        );
        rethrow;
      }
    }
  }

  /// Attempts to restore an existing session using stored credentials.
  /// Called from the notifier when recovering from an unauthenticated state.
  /// Returns true on success.
  Future<bool> tryRestoreSession() async {
    if (_clientId.isEmpty) {
      return false;
    }

    final credentialsJson = _prefs.getString(_credentialsKey);
    if (credentialsJson == null) {
      return false;
    }

    try {
      _reddit = Reddit.restoreInstalledAuthenticatedInstance(
        credentialsJson,
        clientId: _clientId,
        userAgent: kUserAgent,
        redirectUri: Uri.parse(_redirectUri),
      );
      _lastSavedCredentials = credentialsJson;
      await _reddit!.auth.refresh();
      _currentUsername = (await _reddit!.user.me())?.displayName;
      await persistCredentials();
      _authStateController.add(AuthState.loggedIn);
      return true;
    } on Exception catch (e) {
      developer.log(
        'Session restore failed: $e',
        name: 'AuthService',
      );
      return false;
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
        userAgent: kUserAgent,
        redirectUri: Uri.parse(_redirectUri),
      );

      // Generate a cryptographically random state token to prevent CSRF.
      // Each login attempt gets a unique 16-byte (128-bit) random value.
      final stateBytes = List<int>.generate(
        16,
        (_) => Random.secure().nextInt(256),
      );
      final state = base64Url.encode(stateBytes);
      _pendingOAuthState = state;

      final url = redditConfig.auth.url(
        _oauthScopes,
        state,
        compactLogin: true,
      );

      developer.log('Authenticating with URL: $url', name: 'AuthService');

      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: 'com.mohan.reddit.client',
      );

      final callbackUri = Uri.parse(result);
      final returnedState = callbackUri.queryParameters['state'];
      final code = callbackUri.queryParameters['code'];

      // Always clear the pending state once the callback is received.
      final expectedState = _pendingOAuthState;
      _pendingOAuthState = null;

      // Validate state before accepting the auth code.
      if (returnedState == null || returnedState != expectedState) {
        developer.log(
          'OAuth state mismatch — possible CSRF attack. '
          'Expected: $expectedState, Got: $returnedState',
          name: 'AuthService',
        );
        return 'Login failed: invalid OAuth state. Please try again.';
      }

      if (code != null) {
        await _exchangeCodeForToken(code, redditConfig);
        _currentUsername = (await _reddit!.user.me())?.displayName;
        _authStateController.add(AuthState.loggedIn);
        return null; // Success
      } else {
        return 'Login cancelled or no code returned.';
      }
    } on Exception catch (e) {
      _pendingOAuthState = null; // Clean up on any exception
      return 'Login failed: $e';
    }
  }

  /// Exchanges the authorization code for an access token.
  Future<void> _exchangeCodeForToken(String code, Reddit redditInstance) async {
    await redditInstance.auth.authorize(code);
    _reddit = redditInstance;

    final credentialsJson = _reddit!.auth.credentials.toJson();
    await _prefs.setString(_credentialsKey, credentialsJson);
    _lastSavedCredentials = credentialsJson;
  }

  /// Logs out the user by clearing stored credentials.
  Future<void> logout() async {
    await _prefs.remove(_credentialsKey);
    _reddit = null;
    _currentUsername = null;
    _authStateController.add(AuthState.loggedOut);
  }

  /// Closes the auth state stream controller.
  void dispose() {
    unawaited(_authStateController.close());
  }
}
