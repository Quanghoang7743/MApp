import 'package:flutter/material.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.controller,
    this.readOnly = false,
    this.onTap,
    this.valueText,
  });

  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextEditingController? controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? valueText;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark
                  ? const Color(0xFF1D2128).withValues(alpha: 0.86)
                  : Colors.white,
              border: Border.all(
                color: _focused
                    ? const Color(0xFF2A89FF)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.04),
                  blurRadius: _focused ? 24 : 18,
                  spreadRadius: -10,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: widget.readOnly
                ? InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: widget.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Text(
                        (widget.valueText != null &&
                                widget.valueText!.isNotEmpty)
                            ? widget.valueText!
                            : (widget.hintText ?? ''),
                        style:
                            (widget.valueText != null &&
                                widget.valueText!.isNotEmpty)
                            ? theme.textTheme.bodyLarge
                            : theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                : TextField(
                    controller: widget.controller,
                    keyboardType: widget.keyboardType,
                    obscureText: widget.obscureText,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: theme.textTheme.bodyMedium,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
