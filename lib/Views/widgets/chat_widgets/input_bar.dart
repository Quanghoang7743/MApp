import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import 'round_icon.dart';

class InputBar extends StatefulWidget {
  const InputBar({
    super.key,
    required this.isDark,
    required this.conversationId,
    required this.onSend,
  });

  final bool isDark;
  final String conversationId;
  final ValueChanged<String> onSend;

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _typingTimer;
  bool _isTyping = false;

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _sendTypingStatus(true);
    } else if (text.isEmpty && _isTyping) {
      _isTyping = false;
      _sendTypingStatus(false);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _sendTypingStatus(false);
      }
    });
  }

  void _sendTypingStatus(bool isTyping) {
    try {
      final authProvider = context.read<AuthProvider>();
      authProvider.api.conversations.sendTypingStatus(widget.conversationId, {
        'isTyping': isTyping,
      });
    } catch (e) {
      // Ignore API errors for typing status
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF1D2129).withValues(alpha: 0.74)
                    : Colors.white.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  RoundIcon(
                    icon: Icons.add_rounded,
                    color: widget.isDark
                        ? const Color(0xFFffffff)
                        : const Color(0xFF465066),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 42,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _controller,
                        onChanged: _onTextChanged,
                        onSubmitted: (_) => _sendMessage(),
                        style: theme.textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          hintText: 'iMessage style',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: const RoundIcon(
                      icon: Icons.arrow_upward_rounded,
                      color: Colors.white,
                      background: Color(0xFF2A89FF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    widget.onSend(text);
    _controller.clear();
    _onTextChanged('');
  }
}
