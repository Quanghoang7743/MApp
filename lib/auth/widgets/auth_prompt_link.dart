import 'package:flutter/material.dart';

class AuthPromptLink extends StatelessWidget {
  const AuthPromptLink({
    super.key,
    required this.prefix,
    required this.action,
    required this.onTap,
  });

  final String prefix;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(text: '$prefix '),
              TextSpan(
                text: action,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF2A89FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
