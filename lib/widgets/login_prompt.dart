import 'package:flutter/material.dart';

/// A welcome screen prompting the user to log in with Reddit.
class LoginPrompt extends StatelessWidget {
  const LoginPrompt({required this.onLogin, super.key});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
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
            onPressed: onLogin,
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
}
