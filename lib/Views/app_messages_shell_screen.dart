import 'package:flutter/material.dart';

import 'app_chat_list_screen.dart';
import 'app_conversation_screen.dart';

class MessagesShellScreen extends StatefulWidget {
  const MessagesShellScreen({
    super.key,
    required this.onToggleTheme,
    required this.darkModeEnabled,
  });

  final VoidCallback onToggleTheme;
  final bool darkModeEnabled;

  @override
  State<MessagesShellScreen> createState() => _MessagesShellScreenState();
}

class _MessagesShellScreenState extends State<MessagesShellScreen> {
  ConversationSelection? _selection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isTablet = width >= 700;
        if (!isTablet) {
          return ChatListScreen(
            onToggleTheme: widget.onToggleTheme,
            darkModeEnabled: widget.darkModeEnabled,
          );
        }

        final sidebarWidth = width >= 1100
            ? 380.0
            : width >= 900
            ? 340.0
            : 300.0;

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 30,
                      spreadRadius: -12,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Row(
                    children: [
                      SizedBox(
                        width: sidebarWidth,
                        child: ChatListScreen(
                          onToggleTheme: widget.onToggleTheme,
                          darkModeEnabled: widget.darkModeEnabled,
                          embedded: true,
                          selectedConversationId: _selection?.chat.id,
                          onChatSelected: (selection) {
                            setState(() {
                              _selection = selection;
                            });
                          },
                        ),
                      ),
                      Container(width: 1, color: Colors.black12),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _selection == null
                              ? const _ConversationPlaceholder()
                              : ConversationScreen(
                                  key: ValueKey(_selection!.chat.id),
                                  onBack: () {
                                    setState(() {
                                      _selection = null;
                                    });
                                  },
                                  contact: _selection!.chat,
                                  messages: _selection!.messages,
                                  embedded: true,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConversationPlaceholder extends StatelessWidget {
  const _ConversationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F9FA),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 42,
              color: Colors.black38,
            ),
            SizedBox(height: 12),
            Text(
              'Chọn một cuộc trò chuyện',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
