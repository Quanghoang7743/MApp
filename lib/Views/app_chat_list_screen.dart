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
  final ChatCacheService _cacheService = ChatCacheService();
  final TextEditingController _searchController = TextEditingController();

  List<ChatItem> chats = [];
  Map<String, String> _friendNameByUserId = {};
  bool isLoading = true;
  String? errorMessage;
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    _loadCachedChats();
    _fetchConversations();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        String? avatarUrl;
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
          final candidateAvatar =
              (user['avatar_url'] ?? user['avatarUrl'] ?? user['photo_url'])
                  ?.toString();
          if (candidate != null && candidate.trim().isNotEmpty) {
            resolvedName = candidate;
            avatarUrl = candidateAvatar;
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
            avatarUrl: avatarUrl ?? chat.avatarUrl,
            unreadCount: chat.unreadCount,
            isPinned: chat.isPinned,
            isGroup: chat.isGroup,
            isStarred: chat.isStarred,
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
          avatarUrl: chat.avatarUrl,
          unreadCount: chat.unreadCount,
          isPinned: chat.isPinned,
          isGroup: chat.isGroup,
          isStarred: chat.isStarred,
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

  List<ChatItem> _visibleChats() {
    final keyword = _searchController.text.trim().toLowerCase();
    var filtered = chats.where((chat) {
      final matchesSearch =
          keyword.isEmpty ||
          chat.name.toLowerCase().contains(keyword) ||
          chat.message.toLowerCase().contains(keyword);

      if (!matchesSearch) {
        return false;
      }

      switch (_selectedFilter) {
        case 1:
          return chat.unreadCount > 0;
        case 2:
          return chat.isGroup;
        case 3:
          return chat.isStarred;
        default:
          return true;
      }
    }).toList();

    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return 0;
    });
    return filtered;
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label đang được phát triển')));
  }

  Widget _buildBody(List<ChatItem> visibleChats) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFCB3A5D),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (visibleChats.isEmpty) {
      return const Center(
        child: Text(
          'Không có cuộc trò chuyện nào',
          style: TextStyle(color: Color(0xFF8D8DA3), fontSize: 15),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchConversations,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 18),
        itemCount: visibleChats.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final chat = visibleChats[index];
          final displayChat = ChatItem(
            id: chat.id,
            name: chat.name,
            message: chat.message,
            time: _formatTime(chat.time),
            initials: chat.initials,
            isTyping: chat.isTyping,
            avatarUrl: chat.avatarUrl,
            unreadCount: chat.unreadCount,
            isPinned: chat.isPinned,
            isGroup: chat.isGroup,
            isStarred: chat.isStarred,
          );
          final isSelected =
              widget.selectedConversationId != null &&
              widget.selectedConversationId == chat.id;
          return ConversationRow(
            chat: displayChat,
            onTap: () => _openConversation(chat),
            isSelected: isSelected,
            compact: !widget.embedded,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showStarredTab = widget.embedded;
    final visibleChats = _visibleChats();

    final content = DecoratedBox(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        top: !widget.embedded,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            widget.embedded ? 18 : 18,
            widget.embedded ? 18 : 10,
            widget.embedded ? 18 : 18,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _MoxWordmark(),
                  const Spacer(),
                  _SquareIconButton(
                    onTap: () => _showComingSoon('Tạo cuộc trò chuyện'),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF1F2040),
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (!widget.embedded)
                const Text(
                  'Trò chuyện',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1D45),
                    letterSpacing: -0.6,
                  ),
                ),
              if (!widget.embedded) const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _ChatSearchField(controller: _searchController),
                  ),
                  const SizedBox(width: 12),
                  _SquareIconButton(
                    onTap: () => _showComingSoon('Bộ lọc'),
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF444563),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipButton(
                      label: 'Tất cả',
                      selected: _selectedFilter == 0,
                      onTap: () => setState(() => _selectedFilter = 0),
                    ),
                    const SizedBox(width: 12),
                    _FilterChipButton(
                      label: 'Chưa đọc',
                      selected: _selectedFilter == 1,
                      onTap: () => setState(() => _selectedFilter = 1),
                    ),
                    const SizedBox(width: 12),
                    _FilterChipButton(
                      label: 'Nhóm',
                      selected: _selectedFilter == 2,
                      onTap: () => setState(() => _selectedFilter = 2),
                    ),
                    if (showStarredTab) ...[
                      const SizedBox(width: 12),
                      _FilterChipButton(
                        label: 'Gắn sao',
                        selected: _selectedFilter == 3,
                        onTap: () => setState(() => _selectedFilter = 3),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildBody(visibleChats)),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(backgroundColor: const Color(0xFFF8F6FF), body: content);
  }
}

class ConversationSelection {
  const ConversationSelection({required this.chat, required this.messages});

  final ChatItem chat;
  final List<MessageItem> messages;
}

class _MoxWordmark extends StatelessWidget {
  const _MoxWordmark();

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF74A0FF), Color(0xFF7250FF)],
    );

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: gradient.createShader,
      child: const Text(
        'Mox',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.6,
          height: 1,
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.onTap, required this.icon});

  final VoidCallback onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F7FC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(width: 54, height: 54, child: Center(child: icon)),
      ),
    );
  }
}

class _ChatSearchField extends StatelessWidget {
  const _ChatSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Tìm kiếm',
        hintStyle: const TextStyle(color: Color(0xFF979CB3), fontSize: 16),
        filled: true,
        fillColor: const Color(0xFFF3F4F8),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(16),
          child: SvgPicture.asset(
            'assets/icons/search.svg',
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(
              Color(0xFF6A6C87),
              BlendMode.srcIn,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 54,
          minHeight: 54,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFD9D8FF)),
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF5D5BFF), Color(0xFF7A66FF)],
                  )
                : null,
            color: selected ? null : const Color(0xFFF4F5F8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF2A2C45),
            ),
          ),
        ),
      ),
    );
  }
}
