import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/chat_item.dart';
import '../models/message_item.dart';
import '../providers/auth_provider.dart';
import '../providers/contact_sync_provider.dart';
import '../providers/friend_provider.dart';
import '../services/api_client.dart';
import '../services/device_contacts_service.dart';
import 'app_conversation_screen.dart';
import 'widgets/contact_widgets/addfriend_view.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFriends();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _setupContactsPermissionFlow(),
    );
    _searchController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _setupContactsPermissionFlow() async {
    final syncProvider = context.read<ContactSyncProvider>();
    await syncProvider.initialize();
    if (!mounted || !syncProvider.shouldShowPrePermissionPrompt) {
      return;
    }

    await _showContactsEducationPrompt(syncProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFriends() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final response = await authProvider.api.friends.getFriends();
      final list = _extractList(response);

      if (!mounted) {
        return;
      }

      setState(() {
        _friends = list
            .map((item) => _normalizeFriendItem(item))
            .whereType<Map<String, dynamic>>()
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Khong the tai danh sach ban be: $e';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic>? _normalizeFriendItem(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final nestedFriend = raw['friend'];
    if (nestedFriend is Map<String, dynamic>) {
      return nestedFriend;
    }

    final nestedUser = raw['user'];
    if (nestedUser is Map<String, dynamic>) {
      return {...raw, 'user': nestedUser};
    }

    return raw;
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) {
      return response;
    }

    if (response is Map<String, dynamic>) {
      for (final key in const ['data', 'friends', 'items', 'results']) {
        final value = response[key];
        if (value is List) {
          return value;
        }
        if (value is Map<String, dynamic>) {
          final nested = _extractList(value);
          if (nested.isNotEmpty) {
            return nested;
          }
        }
      }

      for (final entry in response.entries) {
        if (entry.value is List) {
          return entry.value as List;
        }
      }
    }

    return const [];
  }

  String _resolveFriendUserId(Map<String, dynamic> friend) {
    final user = friend['user'];
    if (user is Map<String, dynamic>) {
      final id = user['id'] ?? user['user_id'];
      if (id != null && id.toString().isNotEmpty) {
        return id.toString();
      }
    }

    final id = friend['friend_id'] ?? friend['user_id'] ?? friend['id'];
    return id?.toString() ?? '';
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

  Future<void> _openDirectConversation(Map<String, dynamic> friend) async {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = _resolveCurrentUserId(authProvider.user);
    final targetUserId = _resolveFriendUserId(friend);

    if (targetUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khong tim thay user id cua ban be')),
      );
      return;
    }

    try {
      final response = await _createDirectConversationWithFallback(
        authProvider,
        targetUserId,
      );

      final conversationMap = _extractConversationMap(response);
      var chat = ChatItem.fromJson(
        conversationMap,
        currentUserId: currentUserId,
      );

      final friendName = _nameFromFriend(friend);
      if (chat.name.trim().isEmpty ||
          chat.name.trim().toLowerCase() == 'unknown') {
        chat = ChatItem(
          id: chat.id,
          name: friendName,
          message: chat.message,
          time: chat.time,
          initials: _initialsFromName(friendName),
          isTyping: chat.isTyping,
        );
      }

      if (chat.id.isEmpty) {
        throw ApiException(
          statusCode: 422,
          message: 'Khong lay duoc conversation id',
          data: response,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            onBack: () => Navigator.of(context).pop(),
            contact: chat,
            messages: const <MessageItem>[],
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Khong mo duoc chat: ${_readableApiError(e)}')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Khong mo duoc chat: $e')));
    }
  }

  Future<dynamic> _createDirectConversationWithFallback(
    AuthProvider authProvider,
    String targetUserId,
  ) async {
    final payloads = <Map<String, dynamic>>[
      {'user_id': targetUserId},
      {'target_user_id': targetUserId},
      {'friend_id': targetUserId},
      {
        'participant_ids': [targetUserId],
      },
      {
        'participants': [targetUserId],
      },
    ];

    ApiException? lastValidationError;
    for (final payload in payloads) {
      try {
        return await authProvider.api.conversations.createDirectConversation(
          payload,
        );
      } on ApiException catch (e) {
        if (e.statusCode != 422) {
          rethrow;
        }
        lastValidationError = e;
      }
    }

    throw lastValidationError ??
        ApiException(
          statusCode: 422,
          message: 'Validation error create direct conversation',
        );
  }

  Map<String, dynamic> _extractConversationMap(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final nestedConversation = data['conversation'];
        if (nestedConversation is Map<String, dynamic>) {
          return nestedConversation;
        }
        return data;
      }

      final conversation = response['conversation'];
      if (conversation is Map<String, dynamic>) {
        return conversation;
      }

      return response;
    }

    return const {};
  }

  String _readableApiError(ApiException error) {
    final data = error.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final first = errors.entries.first;
        final value = first.value;
        if (value is List && value.isNotEmpty) {
          return '${first.key}: ${value.first}';
        }
        return '${first.key}: $value';
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return error.message;
  }

  String _nameFromFriend(Map<String, dynamic> friend) {
    final user = friend['user'];
    if (user is Map<String, dynamic>) {
      final n =
          user['name'] ??
          user['full_name'] ??
          user['username'] ??
          user['phone_number'];
      if (n is String && n.trim().isNotEmpty) {
        return n;
      }
    }

    final n =
        friend['name'] ??
        friend['full_name'] ??
        friend['username'] ??
        friend['phone_number'];
    if (n is String && n.trim().isNotEmpty) {
      return n;
    }
    return 'Unknown';
  }

  String _initialsFromName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
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

  String _subtitleFromFriend(Map<String, dynamic> friend) {
    final user = friend['user'];
    if (user is Map<String, dynamic>) {
      final phone = user['phone_number'];
      if (phone is String && phone.trim().isNotEmpty) {
        return phone;
      }
      final username = user['username'];
      if (username is String && username.trim().isNotEmpty) {
        return '@$username';
      }
    }

    final phone = friend['phone_number'];
    if (phone is String && phone.trim().isNotEmpty) {
      return phone;
    }

    return 'Ban be';
  }

  List<Map<String, dynamic>> _filteredFriends() {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _friends;
    }

    return _friends.where((friend) {
      final name = _nameFromFriend(friend).toLowerCase();
      final subtitle = _subtitleFromFriend(friend).toLowerCase();
      return name.contains(keyword) || subtitle.contains(keyword);
    }).toList();
  }

  List<_FriendGroup> _groupedFriends(List<Map<String, dynamic>> friends) {
    final sortedFriends = [...friends]
      ..sort((a, b) {
        return _nameFromFriend(
          a,
        ).toLowerCase().compareTo(_nameFromFriend(b).toLowerCase());
      });

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final friend in sortedFriends) {
      final key = _groupKeyForFriend(friend);
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(friend);
    }

    final keys = grouped.keys.toList()..sort();
    return keys
        .map((key) => _FriendGroup(label: key, friends: grouped[key]!))
        .toList();
  }

  String _groupKeyForFriend(Map<String, dynamic> friend) {
    final name = _nameFromFriend(friend).trim();
    if (name.isEmpty) {
      return '#';
    }

    final leading = name.substring(0, 1).toUpperCase();
    if (RegExp(r'[A-Z0-9]').hasMatch(leading)) {
      return leading;
    }
    return '#';
  }

  Future<void> _openAddFriend() async {
    final friendProvider = context.read<FriendProvider>();
    final contactSyncProvider = context.read<ContactSyncProvider>();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: friendProvider),
            ChangeNotifierProvider.value(value: contactSyncProvider),
          ],
          child: const AddFriendView(),
        ),
      ),
    );

    if (result == true && mounted) {
      _fetchFriends();
    }
  }

  Future<void> _showContactsEducationPrompt(
    ContactSyncProvider syncProvider,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cho phép truy cập danh bạ'),
        content: const Text(
          'MoxChat cần quyền danh bạ để đọc toàn bộ số điện thoại trên máy và gợi ý thêm bạn cho bạn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }

    await syncProvider.markPrePermissionPromptHandled();
    if (accepted != true) {
      return;
    }

    final granted = await syncProvider.requestContactsAccess();
    if (!mounted || granted) {
      return;
    }

    final state = syncProvider.permissionState;
    final message =
        state == ContactPermissionState.permanentlyDenied ||
            state == ContactPermissionState.restricted
        ? 'Quyen danh ba da bi tu choi. Hay mo cai dat de cap quyen.'
        : 'Ban chua cap quyen danh ba.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleContactsActionTap(
    ContactSyncProvider syncProvider,
  ) async {
    await syncProvider.initialize();
    if (!mounted || !syncProvider.isSupportedPlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tinh nang nay chi ho tro tren Android va iOS'),
        ),
      );
      return;
    }

    if (syncProvider.shouldShowPrePermissionPrompt) {
      await _showContactsEducationPrompt(syncProvider);
      return;
    }

    if (syncProvider.shouldShowOpenSettings) {
      await syncProvider.openSystemSettings();
      return;
    }

    if (!syncProvider.hasContactsAccess) {
      final granted = await syncProvider.requestContactsAccess();
      if (!mounted || !granted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }
    await _openAddFriend();
  }

  String _contactsActionTitle(ContactSyncProvider syncProvider) {
    if (!syncProvider.isSupportedPlatform) {
      return 'Danh bạ điện thoại';
    }
    if (syncProvider.shouldShowOpenSettings) {
      return 'Mở cài đặt danh bạ';
    }
    if (syncProvider.hasContactsAccess) {
      return 'Danh bạ điện thoại';
    }
    return 'Cho phép danh bạ';
  }

  String _contactsActionSubtitle(ContactSyncProvider syncProvider) {
    if (!syncProvider.isSupportedPlatform) {
      return 'Chi ho tro tren mobile';
    }
    if (syncProvider.shouldShowOpenSettings) {
      return 'Cap quyen tu cai dat he thong';
    }
    if (syncProvider.hasContactsAccess) {
      return syncProvider.lastSyncedAt == null
          ? 'Goi y them ban tu so tren may'
          : 'Da san sang dong bo danh ba';
    }
    return 'Lay tat ca so tren dien thoai';
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label đang được phát triển')));
  }

  Widget _buildContactsContent(List<Map<String, dynamic>> filtered) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: _fetchFriends,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFCB3A5D),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchFriends,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
          children: const [
            Text(
              'Chưa có bạn bè, hãy thêm bạn mới.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8D8DA3), fontSize: 14),
            ),
          ],
        ),
      );
    }

    final groups = _groupedFriends(filtered);
    return RefreshIndicator(
      onRefresh: _fetchFriends,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final group in groups) ...[
            _GroupHeader(label: group.label),
            const SizedBox(height: 14),
            for (final friend in group.friends) ...[
              _ContactRow(
                initials: _initialsFromName(_nameFromFriend(friend)),
                name: _nameFromFriend(friend),
                onTap: () => _openDirectConversation(friend),
                onChatTap: () => _openDirectConversation(friend),
                onCallTap: () => _showComingSoon('Tính năng gọi điện'),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFriends();
    final contactSyncProvider = context.watch<ContactSyncProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Danh bạ',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF181F5A),
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Kết nối với bạn bè của bạn',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8F95B2),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CircleIconButton(
                    onTap: _openAddFriend,
                    icon: SvgPicture.asset(
                      'assets/icons/add-user.svg',
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF624DFF),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              _SearchField(controller: _searchController),
              const SizedBox(height: 22),
              Row(
                children: [
                  // Expanded(
                  //   child: _ActionCard(
                  //     title: _contactsActionTitle(contactSyncProvider),
                  //     subtitle: _contactsActionSubtitle(contactSyncProvider),
                  //     iconBackground: const Color(0xFFE9DDFF),
                  //     icon: SvgPicture.asset(
                  //       'assets/icons/add-user.svg',
                  //       width: 20,
                  //       height: 20,
                  //       colorFilter: const ColorFilter.mode(
                  //         Color(0xFF6E4CFF),
                  //         BlendMode.srcIn,
                  //       ),
                  //     ),
                  //     onTap: () =>
                  //         _handleContactsActionTap(contactSyncProvider),
                  //   ),
                  // ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _ActionCard(
                      title: 'Cuộc gọi gần đây',
                      subtitle: 'Xem lịch sử gọi',
                      iconBackground: const Color(0xFFDDF6F1),
                      icon: SvgPicture.asset(
                        'assets/icons/call-recend.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF33A7A3),
                          BlendMode.srcIn,
                        ),
                      ),
                      onTap: () => _showComingSoon('Cuộc gọi gần đây'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x140D123D),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Danh sách liên hệ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF202552),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF6D58FF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(
                                Icons.swap_vert_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'A–Z',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.tune_rounded,
                                color: Color(0xFF6D74A1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: _buildContactsContent(filtered)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendGroup {
  const _FriendGroup({required this.label, required this.friends});

  final String label;
  final List<Map<String, dynamic>> friends;
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.onTap, required this.icon});

  final VoidCallback onTap;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x120B1044),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Tìm tên, số điện thoại...',
        hintStyle: const TextStyle(color: Color(0xFF8D8DA3), fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(18),
          child: SvgPicture.asset(
            'assets/icons/search.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              Color(0xFF6B4BFF),
              BlendMode.srcIn,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 58,
          minHeight: 58,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: Color(0xFFDCCEFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: Color(0xFF8569FF)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: const BorderSide(color: Color(0xFFDCCEFF)),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.iconBackground,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color iconBackground;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120D123D),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: icon),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D2250),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8B90AD),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6A58D7),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.initials,
    required this.name,
    required this.onTap,
    required this.onChatTap,
    required this.onCallTap,
  });

  final String initials;
  final String name;
  final VoidCallback onTap;
  final VoidCallback onChatTap;
  final VoidCallback onCallTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8DEFF),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6A4DDE),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C2250),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: Color(0xFF49C45F)),
                        SizedBox(width: 8),
                        Text(
                          'Bạn bè',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8D8DA3),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RowActionButton(
                backgroundColor: const Color(0xFFF1EBFF),
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 22,
                  color: Color(0xFF6B4BFF),
                ),
                onTap: onChatTap,
              ),
              const SizedBox(width: 10),
              _RowActionButton(
                backgroundColor: const Color(0xFFE7F9EB),
                icon: SvgPicture.asset(
                  'assets/icons/call.svg',
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF54C067),
                    BlendMode.srcIn,
                  ),
                ),
                onTap: onCallTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowActionButton extends StatelessWidget {
  const _RowActionButton({
    required this.backgroundColor,
    required this.icon,
    required this.onTap,
  });

  final Color backgroundColor;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 46, height: 46, child: Center(child: icon)),
      ),
    );
  }
}
