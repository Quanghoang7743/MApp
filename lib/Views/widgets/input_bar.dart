import 'dart:ui';

import 'package:flutter/material.dart';

import 'round_icon.dart';

class InputBar extends StatelessWidget {
  const InputBar({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1D2129).withValues(alpha: 0.74)
                    : Colors.white.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  RoundIcon(
                    icon: Icons.add_rounded,
                    color: isDark
                        ? const Color(0xFFDEE2EA)
                        : const Color(0xFF465066),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 42,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF262B35).withValues(alpha: 0.8)
                            : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: Text(
                        'iMessage style',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const RoundIcon(
                    icon: Icons.arrow_upward_rounded,
                    color: Colors.white,
                    background: Color(0xFF2A89FF),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
