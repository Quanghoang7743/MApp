import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';

class InputBar extends StatefulWidget {
  const InputBar({
    super.key,
    required this.isDark,
    required this.conversationId,
    required this.onSend,
    required this.onPickPhoto,
    required this.onOpenCamera,
  });

  final bool isDark;
  final String conversationId;
  final ValueChanged<String> onSend;
  final Future<void> Function() onPickPhoto;
  final Future<void> Function() onOpenCamera;

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
    } catch (_) {
      // Ignore API errors for typing status.
    }
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label đang được phát triển')));
  }

  void _showReactionHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nhấn giữ tin nhắn để thả cảm xúc'),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputBackground = widget.isDark
        ? const Color(0xFF1F2330)
        : Colors.white;
    final borderColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8EAF4);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF171B25)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140E123D),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              _IconCircleButton(
                icon: Icons.add_rounded,
                iconColor: const Color(0xFF6E62FF),
                backgroundColor: widget.isDark
                    ? const Color(0xFF23283A)
                    : const Color(0xFFF1EDFF),
                onTap: () => _showComingSoon('Thêm nội dung'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: inputBackground,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onChanged: _onTextChanged,
                          onSubmitted: (_) => _sendMessage(),
                          style: TextStyle(
                            fontSize: 16,
                            color: widget.isDark
                                ? Colors.white
                                : const Color(0xFF1B1F45),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Nhập tin nhắn...',
                            hintStyle: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9A9EB5),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      _InlineIconButton(
                        icon: Icons.sentiment_satisfied_alt_rounded,
                        onTap: _showReactionHint,
                      ),
                      _InlineIconButton(
                        icon: Icons.attach_file_rounded,
                        onTap: () {
                          widget.onPickPhoto();
                        },
                      ),
                      _InlineIconButton(
                        icon: Icons.photo_camera_outlined,
                        onTap: () {
                          widget.onOpenCamera();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _IconCircleButton(
                icon: Icons.send_rounded,
                iconColor: Colors.white,
                backgroundColor: const Color(0xFF6C63FF),
                gradient: const LinearGradient(
                  colors: [Color(0xFF5F61FF), Color(0xFF7A63FF)],
                ),
                onTap: _sendMessage,
              ),
            ],
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

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
    this.gradient,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: gradient == null ? backgroundColor : null,
            gradient: gradient,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 26),
        ),
      ),
    );
  }
}

class _InlineIconButton extends StatelessWidget {
  const _InlineIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      icon: Icon(icon, size: 24, color: const Color(0xFF54597A)),
    );
  }
}
