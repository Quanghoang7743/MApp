import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_item.dart';
import '../models/message_item.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/environment.dart';
import '../services/local/chat_cache_service.dart';
import '../services/realtime/realtime_service.dart';
import 'widgets/chat_widgets/input_bar.dart';
import 'widgets/chat_widgets/message_bubble.dart';
import 'widgets/chat_widgets/typing_indicator.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.onBack,
    required this.contact,
    required this.messages,
    this.embedded = false,
  });

  final VoidCallback onBack;
  final ChatItem contact;
  final List<MessageItem> messages;
  final bool embedded;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late List<MessageItem> _messages;
  late String _contactName;
  final ScrollController _scrollController = ScrollController();
  final RealtimeService _realtime = RealtimeService.instance;
  final ChatCacheService _cacheService = ChatCacheService();
  bool _sending = false;
  bool _peerTyping = false;
  Timer? _typingHideTimer;

  @override
  void initState() {
    super.initState();
    _contactName = widget.contact.name;
    _messages = _sortMessagesByTime(List<MessageItem>.from(widget.messages));
    Future.microtask(_loadCachedMessages);
    Future.microtask(_reloadMessagesFromServer);
    Future.microtask(_resolveContactNameIfUnknown);
    Future.microtask(_setupRealtime);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _loadCachedMessages() async {
    if (widget.contact.id.isEmpty) {
      return;
    }
    final cached = await _cacheService.readMessages(widget.contact.id);
    if (!mounted || cached.isEmpty) {
      return;
    }
    setState(() {
      _messages = _messages.isEmpty
          ? _sortMessagesByTime(cached)
          : _mergeMessages(_messages, cached);
    });
  }

  Future<void> _setupRealtime() async {
    if (widget.contact.id.isEmpty) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await _realtime.ensureConnected(
      apiKey: Environment.realtimeKey,
      cluster: Environment.realtimeCluster.isEmpty
          ? 'mt1'
          : Environment.realtimeCluster,
      useTLS: Environment.realtimeUseTLS,
      authEndpoint: Environment.broadcastingAuthEndpoint,
      tokenProvider: () async => authProvider.token,
    );

    if (Environment.realtimeKey.trim().isEmpty) {
      return;
    }

    await _realtime.subscribeConversation(widget.contact.id);
    _realtime.bindConversationEvent(
      widget.contact.id,
      '.message.created',
      _onRealtimeMessageCreated,
    );
    _realtime.bindConversationEvent(
      widget.contact.id,
      '.message.deleted_for_everyone',
      _onRealtimeMessageDeletedForEveryone,
    );
    _realtime.bindConversationEvent(
      widget.contact.id,
      '.conversation.typing.updated',
      _onRealtimeTypingUpdated,
    );
  }

  void _onRealtimeMessageCreated(RealtimeEvent event) {
    final payload = event.data;
    final conversationId = (payload['conversation_id'] ?? '').toString();
    if (conversationId != widget.contact.id) {
      return;
    }

    final messageRaw = payload['message'];
    if (messageRaw is! Map<String, dynamic>) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final currentUserId = _resolveCurrentUserId(authProvider.user);
    final normalized = <String, dynamic>{
      ...messageRaw,
      'created_at':
          messageRaw['sent_at'] ??
          messageRaw['created_at'] ??
          messageRaw['time'],
    };
    final message = MessageItem.fromJson(
      normalized,
      currentUserId: currentUserId,
    );
    if (message.id.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (message.isMe) {
        _messages.removeWhere(
          (item) =>
              item.id.startsWith('temp-') &&
              item.text.trim() == message.text.trim(),
        );
      }

      final existingIndex = _messages.indexWhere(
        (item) => item.id == message.id,
      );
      if (existingIndex >= 0) {
        _messages[existingIndex] = message;
      } else {
        _messages.add(message);
      }
      _messages = _sortMessagesByTime(_messages);
    });
    _scrollToBottom();
  }

  void _onRealtimeMessageDeletedForEveryone(RealtimeEvent event) {
    final payload = event.data;
    final conversationId = (payload['conversation_id'] ?? '').toString();
    if (conversationId != widget.contact.id) {
      return;
    }

    final messageId = (payload['message_id'] ?? '').toString();
    if (messageId.isEmpty || !mounted) {
      return;
    }

    setState(() {
      final index = _messages.indexWhere((item) => item.id == messageId);
      if (index < 0) {
        return;
      }
      final current = _messages[index];
      _messages[index] = MessageItem(
        id: current.id,
        text: 'Tin nhan da duoc xoa',
        isMe: current.isMe,
        time: current.time,
      );
    });
    _cacheService.saveMessages(widget.contact.id, _messages);
  }

  void _onRealtimeTypingUpdated(RealtimeEvent event) {
    final payload = event.data;
    final conversationId = (payload['conversation_id'] ?? '').toString();
    if (conversationId != widget.contact.id || !mounted) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final currentUserId = _resolveCurrentUserId(authProvider.user);
    final senderId =
        (payload['user_id'] ??
                payload['sender_id'] ??
                payload['participant_id'] ??
                '')
            .toString();
    if (senderId.isNotEmpty && senderId == currentUserId) {
      return;
    }

    final isTyping =
        payload['is_typing'] == true ||
        payload['isTyping'] == true ||
        payload['typing'] == true;
    _typingHideTimer?.cancel();

    setState(() {
      _peerTyping = isTyping;
    });

    if (isTyping) {
      _typingHideTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _peerTyping = false;
        });
      });
    }
  }

  Future<void> _resolveContactNameIfUnknown() async {
    final current = _contactName.trim().toLowerCase();
    if (current.isNotEmpty && current != 'unknown') {
      return;
    }

    if (widget.contact.id.isEmpty) {
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = _resolveCurrentUserId(authProvider.user);
      final response = await authProvider.api.participants.getParticipants(
        widget.contact.id,
      );
      final participants = _extractList(
        response,
      ).whereType<Map<String, dynamic>>().toList();

      String? resolvedName;
      for (final participant in participants) {
        final user = participant['user'] is Map<String, dynamic>
            ? participant['user'] as Map<String, dynamic>
            : participant;
        final userId = (user['id'] ?? user['user_id'] ?? '').toString();
        if (userId.isNotEmpty && userId == currentUserId) {
          continue;
        }

        final candidate =
            (user['name'] ??
                    user['full_name'] ??
                    user['fullName'] ??
                    user['username'] ??
                    user['phone_number'])
                ?.toString();
        if (candidate != null && candidate.trim().isNotEmpty) {
          resolvedName = candidate;
          break;
        }
      }

      if (resolvedName != null && mounted) {
        setState(() {
          _contactName = resolvedName!;
        });
      }
    } catch (_) {
      // keep fallback name
    }
  }

  String _displayInitials() {
    final name = _contactName.trim();
    if (name.isEmpty || name.toLowerCase() == 'unknown') {
      return widget.contact.initials;
    }

    final parts = name
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return widget.contact.initials;
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  void dispose() {
    _typingHideTimer?.cancel();
    _realtime.unbindConversationEvent(
      widget.contact.id,
      '.message.created',
      _onRealtimeMessageCreated,
    );
    _realtime.unbindConversationEvent(
      widget.contact.id,
      '.message.deleted_for_everyone',
      _onRealtimeMessageDeletedForEveryone,
    );
    _realtime.unbindConversationEvent(
      widget.contact.id,
      '.conversation.typing.updated',
      _onRealtimeTypingUpdated,
    );
    _realtime.unsubscribeConversation(widget.contact.id);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend(String text) async {
    if (widget.contact.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khong tim thay conversation id')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final userId = _resolveCurrentUserId(authProvider.user);

    final optimistic = MessageItem(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isMe: true,
      time: DateTime.now().toIso8601String(),
    );

    setState(() {
      _messages.add(optimistic);
      _messages = _sortMessagesByTime(_messages);
      _sending = true;
    });
    await _cacheService.saveMessages(widget.contact.id, _messages);
    _scrollToBottom();

    try {
      final response = await _sendMessageWithFallback(authProvider, text);

      final payload = _extractMessagePayload(response);
      if (payload != null && mounted) {
        var serverMessage = MessageItem.fromJson(
          payload,
          currentUserId: userId,
        );

        if (serverMessage.text.trim().isEmpty) {
          serverMessage = MessageItem(
            id: serverMessage.id.isNotEmpty ? serverMessage.id : optimistic.id,
            text: optimistic.text,
            isMe: true,
            time: serverMessage.time.isNotEmpty
                ? serverMessage.time
                : optimistic.time,
          );
        }

        setState(() {
          _messages.removeWhere((item) => item.id == optimistic.id);
          _messages.add(serverMessage);
          _messages = _sortMessagesByTime(_messages);
        });
        await _cacheService.saveMessages(widget.contact.id, _messages);
        _scrollToBottom();
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.removeWhere((item) => item.id == optimistic.id);
        _messages = _sortMessagesByTime(_messages);
      });
      await _cacheService.saveMessages(widget.contact.id, _messages);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gui tin nhan that bai: ${_readableApiError(e)}'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.removeWhere((item) => item.id == optimistic.id);
        _messages = _sortMessagesByTime(_messages);
      });
      await _cacheService.saveMessages(widget.contact.id, _messages);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gui tin nhan that bai: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<dynamic> _sendMessageWithFallback(
    AuthProvider authProvider,
    String text,
  ) async {
    final payloads = <Map<String, dynamic>>[
      {'content': text},
      {'content': text, 'type': 'text'},
      {'content': text, 'message_type': 'text'},
      {'text': text},
      {'message': text},
      {'body': text},
      {
        'content': text,
        'text': text,
        'message': text,
        'body': text,
        'type': 'text',
        'message_type': 'text',
      },
      {
        'content': {'text': text},
        'type': 'text',
      },
      {
        'content': {'text': text, 'type': 'text'},
      },
      {
        'data': {'content': text, 'type': 'text'},
      },
    ];

    ApiException? firstValidationError;
    ApiException? lastValidationError;

    for (final payload in payloads) {
      try {
        return await authProvider.api.messages.sendMessage(
          widget.contact.id,
          payload,
        );
      } on ApiException catch (e) {
        if (e.statusCode != 422) {
          rethrow;
        }
        firstValidationError ??= e;
        lastValidationError = e;
      }
    }

    throw firstValidationError ??
        lastValidationError ??
        ApiException(
          statusCode: 422,
          message: 'Validation error when sending message',
        );
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

  Map<String, dynamic>? _extractMessagePayload(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      final message = response['message'];
      if (message is Map<String, dynamic>) {
        return message;
      }
      return response;
    }
    return null;
  }

  Future<void> _reloadMessagesFromServer() async {
    if (widget.contact.id.isEmpty) {
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = _resolveCurrentUserId(authProvider.user);
      final response = await authProvider.api.messages.getMessages(
        widget.contact.id,
      );
      final data = _extractList(response);

      final mapped = data
          .whereType<Map<String, dynamic>>()
          .map((item) => MessageItem.fromJson(item, currentUserId: userId))
          .toList();

      if (!mounted || mapped.isEmpty) {
        return;
      }

      setState(() {
        final currentById = <String, MessageItem>{
          for (final item in _messages)
            if (item.id.isNotEmpty) item.id: item,
        };

        for (final serverItem in mapped) {
          if (serverItem.id.isEmpty) {
            continue;
          }

          final existing = currentById[serverItem.id];
          if (existing != null &&
              existing.text.trim().isNotEmpty &&
              serverItem.text.trim().isEmpty) {
            continue;
          }
          currentById[serverItem.id] = serverItem;
        }

        final merged = <MessageItem>[];
        final seenIds = <String>{};

        for (final local in _messages) {
          if (local.id.isEmpty) {
            merged.add(local);
            continue;
          }

          final resolved = currentById[local.id] ?? local;
          merged.add(resolved);
          seenIds.add(local.id);
        }

        for (final serverItem in mapped) {
          if (serverItem.id.isEmpty || seenIds.contains(serverItem.id)) {
            continue;
          }
          merged.add(serverItem);
        }

        _messages = _mergeMessages(_messages, mapped);
      });
      await _cacheService.saveMessages(widget.contact.id, _messages);
      _scrollToBottom();
    } catch (_) {
      // Keep current local messages when reload fails.
    }
  }

  List<MessageItem> _sortMessagesByTime(List<MessageItem> messages) {
    final list = List<MessageItem>.from(messages);
    list.sort((a, b) {
      final at = DateTime.tryParse(a.time);
      final bt = DateTime.tryParse(b.time);

      if (at != null && bt != null) {
        return at.compareTo(bt);
      }
      if (at != null) {
        return -1;
      }
      if (bt != null) {
        return 1;
      }
      return 0;
    });
    return list;
  }

  List<MessageItem> _mergeMessages(
    List<MessageItem> current,
    List<MessageItem> incoming,
  ) {
    final byId = <String, MessageItem>{};
    final tempMessages = <MessageItem>[];

    for (final item in current) {
      if (item.id.startsWith('temp-')) {
        tempMessages.add(item);
      } else if (item.id.isNotEmpty) {
        byId[item.id] = item;
      }
    }

    for (final item in incoming) {
      if (item.id.isNotEmpty) {
        byId[item.id] = item;
      }
    }

    return _sortMessagesByTime([...byId.values, ...tempMessages]);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
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

  String? _avatarUrl() {
    final avatar = widget.contact.avatarUrl;
    if (avatar != null && avatar.trim().isNotEmpty) {
      return avatar;
    }
    return null;
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label đang được phát triển')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lastOwnMessage = _messages.lastWhere(
      (message) => message.isMe,
      orElse: () => const MessageItem(id: '', text: '', isMe: false, time: ''),
    );

    final content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF101216), const Color(0xFF171B24)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF6F7FB)],
        ),
      ),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 22,
                      color: Color(0xFF1C2146),
                    ),
                  ),
                  _ConversationAvatar(
                    avatarUrl: _avatarUrl(),
                    initials: _displayInitials(),
                    size: widget.embedded ? 52 : 54,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _contactName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1D45),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Đang hoạt động',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8187A4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      if (widget.embedded)
                        IconButton(
                          onPressed: () => _showComingSoon('Tìm kiếm'),
                          icon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF171C44),
                            size: 28,
                          ),
                        ),
                      IconButton(
                        onPressed: () => _showComingSoon('Gọi thoại'),
                        icon: const Icon(
                          Icons.call_outlined,
                          color: Color(0xFF171C44),
                          size: 28,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showComingSoon('Gọi video'),
                        icon: const Icon(
                          Icons.videocam_outlined,
                          color: Color(0xFF171C44),
                          size: 30,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showComingSoon('Tuỳ chọn'),
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Color(0xFF171C44),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                widget.embedded ? 24 : 16,
                16,
                widget.embedded ? 24 : 16,
                16,
              ),
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EEF9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Hôm nay',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6E7291),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final message = _messages[index - 1];
                final displayMessage = MessageItem(
                  id: message.id,
                  text: message.text,
                  isMe: message.isMe,
                  time: _formatTime(message.time),
                );
                final isSendingMessage =
                    _sending && message.id.startsWith('temp-');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: MessageBubble(
                    message: displayMessage,
                    isSending: isSendingMessage,
                    peerInitials: _displayInitials(),
                    peerAvatarUrl: _avatarUrl(),
                    showSeen:
                        lastOwnMessage.id.isNotEmpty &&
                        lastOwnMessage.id == message.id,
                  ),
                );
              },
            ),
          ),
          if (_peerTyping)
            Padding(
              padding: EdgeInsets.only(
                left: widget.embedded ? 24 : 16,
                right: 16,
                bottom: 8,
              ),
              child: Row(
                children: [
                  _ConversationAvatar(
                    avatarUrl: _avatarUrl(),
                    initials: _displayInitials(),
                    size: 40,
                  ),
                  const SizedBox(width: 10),
                  const TypingIndicator(),
                ],
              ),
            ),
          InputBar(
            isDark: isDark,
            conversationId: widget.contact.id,
            onSend: _handleSend,
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(backgroundColor: const Color(0xFFF8F6FF), body: content);
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({
    required this.avatarUrl,
    required this.initials,
    required this.size,
  });

  final String? avatarUrl;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE7EAF4),
          ),
          child: avatarUrl != null && avatarUrl!.trim().isNotEmpty
              ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _ConversationAvatarFallback(
                        initials: initials,
                        size: size,
                      ),
                )
              : _ConversationAvatarFallback(initials: initials, size: size),
        ),
        const Positioned(
          right: 2,
          bottom: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF5CDD73),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 12, height: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConversationAvatarFallback extends StatelessWidget {
  const _ConversationAvatarFallback({
    required this.initials,
    required this.size,
  });

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6251CC),
        ),
      ),
    );
  }
}
