import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_item.dart';
import '../models/message_item.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages = _sortMessagesByTime(List<MessageItem>.from(widget.messages));
    Future.microtask(_reloadMessagesFromServer);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
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
                    Expanded(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isDark
                                ? const Color(0xFF2B313A)
                                : const Color(0xFFE7EBF2),
                            child: Text(
                              widget.contact.initials,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.contact.name,
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    // SizedBox(
                    //   width: 48,
                    //   child: _sending
                    //       ? const SizedBox(
                    //           width: 16,
                    //           height: 16,
                    //           child: CircularProgressIndicator(strokeWidth: 2),
                    //         )
                    //       : const SizedBox.shrink(),
                    // ),
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
                  final isSendingMessage =
                      _sending && message.id.startsWith('temp-');
                  return MessageBubble(
                    message: message,
                    isSending: isSendingMessage,
                  );
                },
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
