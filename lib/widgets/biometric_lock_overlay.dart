import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yarc/notifiers/biometric_lock_notifier.dart';

/// Overlays a lock screen on top of [child] when [BiometricLockNotifier] is
/// locked. Shown at the [MaterialApp] builder level so it covers the entire
/// app, including the navigation stack.
class BiometricLockOverlay extends StatelessWidget {
  const BiometricLockOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLocked = context.select<BiometricLockNotifier, bool>(
      (n) => n.isLocked,
    );

    return Stack(
      children: [
        child,
        if (isLocked) const _LockScreen(),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAuthenticating = context.select<BiometricLockNotifier, bool>(
      (n) => n.isAuthenticating,
    );
    final errorMessage = context.select<BiometricLockNotifier, String?>(
      (n) => n.errorMessage,
    );

    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 72,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'NSFW Content Locked',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Authenticate to continue viewing this subreddit.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (isAuthenticating)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: () {
                      unawaited(
                        context.read<BiometricLockNotifier>().authenticate(),
                      );
                    },
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock'),
                  ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    errorMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
