import 'package:flutter/material.dart';

/// A welcome/re-auth screen that adapts to the authentication state.
///
/// When [isSessionExpired] is false (default), shows the initial login prompt.
/// When true, shows a "session expired" message with both Retry and Re-login.
class LoginPrompt extends StatefulWidget {
  const LoginPrompt({
    required this.onLogin,
    super.key,
    this.onRetry,
    this.isSessionExpired = false,
  });

  final VoidCallback onLogin;

  /// Called when the user taps "Retry" on the session-expired screen.
  final VoidCallback? onRetry;

  /// Whether to show the session-expired variant.
  final bool isSessionExpired;

  @override
  State<LoginPrompt> createState() => _LoginPromptState();
}

class _LoginPromptState extends State<LoginPrompt> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isSessionExpired) {
      return _buildSessionExpired(context);
    }
    return _buildLogin(context);
  }

  Widget _buildLogin(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.reddit, size: 80, color: Colors.deepOrange),
          const SizedBox(height: 24),
          Text(
            'Welcome to YARC',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: widget.onLogin,
            icon: const Icon(Icons.login),
            label: const Text('Login with Reddit'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionExpired(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Session Expired',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your session has expired or was revoked.\n'
              'Try reconnecting, or log in again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (widget.onRetry != null)
              FilledButton.icon(
                onPressed: _isRetrying
                    ? null
                    : () {
                        setState(() => _isRetrying = true);
                        widget.onRetry!();
                        // The notifier stream will rebuild the widget tree
                        // if retry succeeds. Reset state after a delay in case
                        // it fails silently.
                        Future<void>.delayed(
                          const Duration(seconds: 3),
                          () {
                            if (mounted) {
                              setState(() => _isRetrying = false);
                            }
                          },
                        );
                      },
                icon: _isRetrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_isRetrying ? 'Reconnecting...' : 'Retry'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onLogin,
              icon: const Icon(Icons.login),
              label: const Text('Log in again'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
