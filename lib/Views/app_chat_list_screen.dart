import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/chat_item.dart';
import '../models/message_item.dart';
import '../providers/auth_provider.dart';
import 'app_conversation_screen.dart';
import 'widgets/chat_widgets/conversation_row.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.onToggleTheme,
    required this.darkModeEnabled,
  });

  final VoidCallback onToggleTheme;
  final bool darkModeEnabled;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatItem> chats = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = _resolveCurrentUserId(authProvider.user);
      final response = await authProvider.api.conversations.getConversations();

      final data = _extractList(response);
      final mapped = data
          .whereType<Map<String, dynamic>>()
          .map((item) => ChatItem.fromJson(item, currentUserId: currentUserId))
          .toList();

      if (!mounted) {
        return;
      }
      setState(() {
        chats = mapped;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = 'Loi tai danh sach: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _openConversation(ChatItem chat) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = _resolveCurrentUserId(authProvider.user);
      final response = await authProvider.api.messages.getMessages(chat.id);
      final data = _extractList(response);

      final messages = data
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => MessageItem.fromJson(item, currentUserId: currentUserId),
          )
          .toList();

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            onBack: () => Navigator.of(context).pop(),
            contact: chat,
            messages: messages,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Khong tai duoc tin nhan: $e')));
    }
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) {
      return response;
    }
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) {
        return data;
      }
      if (data is Map<String, dynamic>) {
        final nested = data['data'];
        if (nested is List) {
          return nested;
        }
      }
    }
    return const [];
  }

  String _resolveCurrentUserId(Map<String, dynamic>? user) {
    if (user == null) {
      return '';
    }

    final direct = user['id'] ?? user['user_id'];
    if (direct != null && direct.toString().isNotEmpty) {
      return direct.toString();
    }

    final nestedUser = user['user'];
    if (nestedUser is Map<String, dynamic>) {
      final nestedId = nestedUser['id'] ?? nestedUser['user_id'];
      if (nestedId != null && nestedId.toString().isNotEmpty) {
        return nestedId.toString();
      }
    }

    final data = user['data'];
    if (data is Map<String, dynamic>) {
      final dataId = data['id'] ?? data['user_id'];
      if (dataId != null && dataId.toString().isNotEmpty) {
        return dataId.toString();
      }
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF111318), const Color(0xFF171B21)]
                : [const Color(0xFFF9FAFC), const Color(0xFFF2F4F8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Sửa',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Mox',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/qr-scanner.svg',
                        width: 30,
                        height: 30,
                        colorFilter: const ColorFilter.mode(
                          Colors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : errorMessage != null
                      ? Center(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : chats.isEmpty
                      ? const Center(
                          child: Text('Khong co cuoc tro chuyen nao'),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: chats.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            return ConversationRow(
                              chat: chat,
                              onTap: () => _openConversation(chat),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
