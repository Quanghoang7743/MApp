import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/chat_item.dart';
import '../models/message_item.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/environment.dart';
import '../services/realtime/realtime_service.dart';
import 'widgets/chat_widgets/input_bar.dart';
import 'widgets/chat_widgets/message_bubble.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.onBack,
    required this.contact,
    required this.messages,
  });

  final VoidCallback onBack;
  final ChatItem contact;
  final List<MessageItem> messages;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  late List<MessageItem> _messages;
  late String _contactName;
  final ScrollController _scrollController = ScrollController();
  final RealtimeService _realtime = RealtimeService.instance;
  bool _sending = false;
  bool _peerTyping = false;
  Timer? _typingHideTimer;

  @override
  void initState() {
    super.initState();
    _contactName = widget.contact.name;
    _messages = _sortMessagesByTime(List<MessageItem>.from(widget.messages));
    Future.microtask(_reloadMessagesFromServer);
    Future.microtask(_resolveContactNameIfUnknown);
    Future.microtask(_setupRealtime);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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

        _messages = merged;
        _messages = _sortMessagesByTime(_messages);
      });
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
                ? [const Color(0xFF101216), const Color(0xFF161A21)]
                : [const Color(0xFFFFFFFF), const Color(0xFFF5F7FB)],
          ),
        ),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                    ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isDark
                          ? const Color(0xFF2B313A)
                          : const Color(0xFFE7EBF2),
                      child: Text(
                        _displayInitials(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_contactName, style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/icons/call.svg',
                            width: 20,
                            height: 20,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: SvgPicture.asset(
                            'assets/icons/video-call.svg',
                            width: 25,
                            height: 25,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                itemCount: _messages.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final displayMessage = MessageItem(
                    id: message.id,
                    text: message.text,
                    isMe: message.isMe,
                    time: _formatTime(message.time),
                  );
                  final isSendingMessage =
                      _sending && message.id.startsWith('temp-');
                  return MessageBubble(
                    message: displayMessage,
                    isSending: isSendingMessage,
                  );
                },
              ),
            ),
            if (_peerTyping)
              const Padding(
                padding: EdgeInsets.only(left: 20, right: 20, bottom: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'dang go tin nhan...',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ),
            InputBar(
              isDark: isDark,
              conversationId: widget.contact.id,
              onSend: _handleSend,
            ),
          ],
        ),
      ),
    );
  }
}
