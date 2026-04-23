import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/chat_item.dart';
import '../models/message_item.dart';
import '../providers/auth_provider.dart';
import '../providers/friend_provider.dart';
import '../services/api_client.dart';
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFriends();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Danh bạ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  // const Spacer(),
                  // ElevatedButton.icon(
                  //   onPressed: () {},
                  //   icon: const Icon(Icons.add),
                  //   label: const Text('Add'),
                  // ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: const TextStyle(color: Colors.black45),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final friendProvider = context.read<FriendProvider>();
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChangeNotifierProvider.value(
                                    value: friendProvider,
                                    child: const AddFriendView(),
                                  ),
                            ),
                          );
                          if (result == true && mounted) {
                            _fetchFriends();
                          }
                        },
                        icon: SvgPicture.asset(
                          'assets/icons/add-user.svg',
                          width: 20,
                          height: 20,
                        ),
                        label: const Text('Thêm bạn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black87,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 15,
                          ),
                          minimumSize: const Size(double.infinity, 0),
                          alignment: Alignment.centerLeft,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: SvgPicture.asset(
                          'assets/icons/call-recend.svg',
                          width: 20,
                          height: 20,
                        ),
                        label: const Text('Cuộc gọi gần đây'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.black87,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 15,
                          ),
                          minimumSize: const Size(double.infinity, 0),
                          alignment: Alignment.centerLeft,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: RefreshIndicator(
                      onRefresh: _fetchFriends,
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
                          ? ListView(
                              children: [
                                // const SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            )
                          : filtered.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    'Chưa có bạn bè hãy thêm thôi nào!',
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                              itemBuilder: (context, index) {
                                final friend = filtered[index];
                                final name = _nameFromFriend(friend);
                                final subtitle = _subtitleFromFriend(friend);
                                final initials = name.isNotEmpty
                                    ? name.trim().substring(0, 1).toUpperCase()
                                    : '?';

                                return ListTile(
                                  onTap: () => _openDirectConversation(friend),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFE8ECF4),
                                    child: Text(initials),
                                  ),
                                  title: Text(name),
                                  subtitle: Text(subtitle),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
