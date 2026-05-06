import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/chat_item.dart';
import '../models/message_item.dart';
import '../providers/auth_provider.dart';
import '../services/local/chat_cache_service.dart';
import 'app_conversation_screen.dart';
import 'widgets/chat_widgets/conversation_row.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.onToggleTheme,
    required this.darkModeEnabled,
    this.onChatSelected,
    this.selectedConversationId,
    this.embedded = false,
  });

  final VoidCallback onToggleTheme;
  final bool darkModeEnabled;
  final ValueChanged<ConversationSelection>? onChatSelected;
  final String? selectedConversationId;
  final bool embedded;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatItem> chats = [];
  Map<String, String> _friendNameByUserId = {};
  final ChatCacheService _cacheService = ChatCacheService();
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCachedChats();
    _fetchConversations();
  }

  Future<void> _loadCachedChats() async {
    final cached = await _cacheService.readChats();
    if (!mounted || cached.isEmpty) {
      return;
    }
    setState(() {
      chats = cached;
      isLoading = false;
    });
  }

  Future<void> _fetchConversations() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = _resolveCurrentUserId(authProvider.user);

      try {
        final friendsResponse = await authProvider.api.friends.getFriends();
        final friendsList = _extractList(friendsResponse);
        _friendNameByUserId = _buildFriendNameMap(friendsList);
      } catch (_) {
        _friendNameByUserId = {};
      }

      final response = await authProvider.api.conversations.getConversations();

      final data = _extractList(response);
      final rawConversations = data.whereType<Map<String, dynamic>>().toList();
      final mapped = rawConversations.map((item) {
        final chat = ChatItem.fromJson(item, currentUserId: currentUserId);
        return _resolveUnknownChatName(chat, item, currentUserId);
      }).toList();

      final resolvedByParticipants = await _resolveUnknownNamesByParticipants(
        authProvider,
        mapped,
        currentUserId,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        chats = resolvedByParticipants;
        isLoading = false;
      });
      await _cacheService.saveChats(resolvedByParticipants);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        errorMessage = chats.isEmpty ? 'Loi tai danh sach: $e' : null;
        isLoading = false;
      });
    }
  }

  Future<List<ChatItem>> _resolveUnknownNamesByParticipants(
    AuthProvider authProvider,
    List<ChatItem> input,
    String currentUserId,
  ) async {
    final result = List<ChatItem>.from(input);

    for (var i = 0; i < result.length; i++) {
      final chat = result[i];
      if (chat.id.isEmpty) {
        continue;
      }
      if (chat.name.trim().isNotEmpty &&
          chat.name.trim().toLowerCase() != 'unknown') {
        continue;
      }

      try {
        final participantsResponse = await authProvider.api.participants
            .getParticipants(chat.id);
        final participants = _extractList(
          participantsResponse,
        ).whereType<Map<String, dynamic>>();

        String? resolvedName;
        for (final p in participants) {
          final user = p['user'] is Map<String, dynamic>
              ? p['user'] as Map<String, dynamic>
              : p;
          final userId = (user['id'] ?? user['user_id'] ?? '').toString();
          if (userId.isNotEmpty && userId == currentUserId) {
            continue;
          }

          final candidate =
              (user['name'] ??
                      user['full_name'] ??
                      user['fullName'] ??
                      user['display_name'] ??
                      user['username'] ??
                      user['phone_number'])
                  ?.toString();
          if (candidate != null && candidate.trim().isNotEmpty) {
            resolvedName = candidate;
            _friendNameByUserId[userId] = candidate;
            break;
          }
        }

        if (resolvedName != null) {
          result[i] = ChatItem(
            id: chat.id,
            name: resolvedName,
            message: chat.message,
            time: chat.time,
            initials: _initialsFromName(resolvedName),
            isTyping: chat.isTyping,
          );
        }
      } catch (_) {
        // Keep fallback Unknown for this item when participant API fails.
      }
    }

    return result;
  }

  Map<String, String> _buildFriendNameMap(List<dynamic> friends) {
    final result = <String, String>{};

    for (final item in friends) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final normalized = _normalizeFriendItem(item);
      if (normalized == null) {
        continue;
      }

      final user = normalized['user'];
      final userMap = user is Map<String, dynamic> ? user : normalized;
      final id =
          (userMap['id'] ??
                  userMap['user_id'] ??
                  normalized['friend_id'] ??
                  normalized['contact_id'])
              ?.toString();
      final name =
          (userMap['name'] ??
                  userMap['full_name'] ??
                  userMap['fullName'] ??
                  userMap['display_name'] ??
                  userMap['username'] ??
                  normalized['name'])
              ?.toString();

      if (id != null &&
          id.isNotEmpty &&
          name != null &&
          name.trim().isNotEmpty) {
        result[id] = name;
      }
    }

    return result;
  }

  Map<String, dynamic>? _normalizeFriendItem(Map<String, dynamic> raw) {
    final nestedFriend = raw['friend'];
    if (nestedFriend is Map<String, dynamic>) {
      final user = nestedFriend['user'];
      if (user is Map<String, dynamic>) {
        return {...nestedFriend, 'user': user};
      }
      return nestedFriend;
    }

    final nestedContact = raw['contact'];
    if (nestedContact is Map<String, dynamic>) {
      return nestedContact;
    }

    final nestedUser = raw['user'];
    if (nestedUser is Map<String, dynamic>) {
      return {...raw, 'user': nestedUser};
    }

    return raw;
  }

  ChatItem _resolveUnknownChatName(
    ChatItem chat,
    Map<String, dynamic> raw,
    String currentUserId,
  ) {
    final trimmedName = chat.name.trim().toLowerCase();
    if (trimmedName.isNotEmpty && trimmedName != 'unknown') {
      return chat;
    }

    final source = raw['conversation'] is Map<String, dynamic>
        ? raw['conversation'] as Map<String, dynamic>
        : raw;
    final userIds = _extractRelatedUserIds(source);

    for (final id in userIds) {
      if (id.isEmpty || id == currentUserId) {
        continue;
      }

      final mappedName = _friendNameByUserId[id];
      if (mappedName != null && mappedName.trim().isNotEmpty) {
        return ChatItem(
          id: chat.id,
          name: mappedName,
          message: chat.message,
          time: chat.time,
          initials: _initialsFromName(mappedName),
          isTyping: chat.isTyping,
        );
      }
    }

    return chat;
  }

  List<String> _extractRelatedUserIds(Map<String, dynamic> conversation) {
    final ids = <String>{};

    for (final key in const [
      'user_id',
      'target_user_id',
      'other_user_id',
      'friend_id',
      'recipient_id',
    ]) {
      final value = conversation[key];
      if (value != null && value.toString().isNotEmpty) {
        ids.add(value.toString());
      }
    }

    final participantIds = conversation['participant_ids'];
    if (participantIds is List) {
      for (final item in participantIds) {
        if (item != null && item.toString().isNotEmpty) {
          ids.add(item.toString());
        }
      }
    }

    final participants = conversation['participants'];
    if (participants is List) {
      for (final item in participants) {
        if (item is Map<String, dynamic>) {
          final directId = item['id'] ?? item['user_id'];
          if (directId != null && directId.toString().isNotEmpty) {
            ids.add(directId.toString());
          }

          final user = item['user'];
          if (user is Map<String, dynamic>) {
            final nestedId = user['id'] ?? user['user_id'];
            if (nestedId != null && nestedId.toString().isNotEmpty) {
              ids.add(nestedId.toString());
            }
          }
        }
      }
    }

    return ids.toList();
  }

  String _initialsFromName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Future<void> _openConversation(ChatItem chat) async {
    try {
      final cachedMessages = await _cacheService.readMessages(chat.id);

      if (!mounted) {
        return;
      }

      if (widget.onChatSelected != null) {
        widget.onChatSelected!(
          ConversationSelection(chat: chat, messages: cachedMessages),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            onBack: () => Navigator.of(context).pop(),
            contact: chat,
            messages: cachedMessages,
            embedded: false,
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
      for (final key in const ['data', 'items', 'results', 'participants']) {
        final data = response[key];
        if (data is List) {
          return data;
        }
        if (data is Map<String, dynamic>) {
          final nested = _extractList(data);
          if (nested.isNotEmpty) {
            return nested;
          }
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

  String _formatTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      final local = parsed.toLocal();
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    final match = RegExp(r'(\d{2}):(\d{2})').firstMatch(raw);
    if (match != null) {
      return '${match.group(1)}:${match.group(2)}';
    }

    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = DecoratedBox(
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
                    ? const Center(child: Text('Không có cuộc trò chuyện nào'))
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: chats.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final displayChat = ChatItem(
                            id: chat.id,
                            name: chat.name,
                            message: chat.message,
                            time: _formatTime(chat.time),
                            initials: chat.initials,
                            isTyping: chat.isTyping,
                          );
                          final isSelected =
                              widget.selectedConversationId != null &&
                              widget.selectedConversationId == chat.id;
                          return ConversationRow(
                            chat: displayChat,
                            onTap: () => _openConversation(chat),
                            isSelected: isSelected,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      body: DecoratedBox(decoration: const BoxDecoration(), child: content),
    );
  }
}

class ConversationSelection {
  const ConversationSelection({required this.chat, required this.messages});

  final ChatItem chat;
  final List<MessageItem> messages;
}
