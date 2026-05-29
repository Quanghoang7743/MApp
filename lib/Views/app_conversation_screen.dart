import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/chat_item.dart';
import '../models/message_item.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/environment.dart';
import '../services/local/chat_cache_service.dart';
import '../services/realtime/realtime_service.dart';
import 'widgets/chat_widgets/conversation_avatar.dart';
import 'widgets/chat_widgets/conversation_header.dart';
import 'widgets/chat_widgets/conversation_helpers.dart';
import 'widgets/chat_widgets/input_bar.dart';
import 'widgets/chat_widgets/message_list.dart';
import 'widgets/chat_widgets/reaction_picker.dart';
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
  static const List<String> _messageRefreshEvents = [
    '.message.updated',
    '.message.reaction.updated',
    '.message.attachment.created',
    '.message.attachment.updated',
    '.message.attachment.deleted',
  ];

  late List<MessageItem> _messages;
  late String _contactName;
  final ScrollController _scrollController = ScrollController();
  final RealtimeService _realtime = RealtimeService.instance;
  final ChatCacheService _cacheService = ChatCacheService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _sending = false;
  bool _peerTyping = false;
  Timer? _typingHideTimer;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

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
    for (final eventName in _messageRefreshEvents) {
      _realtime.unbindConversationEvent(
        widget.contact.id,
        eventName,
        _onRealtimeMessageMutated,
      );
    }
    _realtime.unsubscribeConversation(widget.contact.id);
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Cache & server loading
  // ---------------------------------------------------------------------------

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

  Future<void> _reloadMessagesFromServer() async {
    if (widget.contact.id.isEmpty) {
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = resolveCurrentUserId(authProvider.user);
      final response = await authProvider.api.messages.getMessages(
        widget.contact.id,
      );
      final data = extractList(response);

      final mapped = data
          .whereType<Map<String, dynamic>>()
          .map((item) => MessageItem.fromJson(item, currentUserId: userId))
          .toList();

      if (!mounted || mapped.isEmpty) {
        return;
      }

      setState(() {
        _messages = _mergeMessages(_messages, mapped);
      });
      await _persistMessages();
      _scrollToBottom();
    } catch (_) {
      // Keep current local messages when reload fails.
    }
  }

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

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
    for (final eventName in _messageRefreshEvents) {
      _realtime.bindConversationEvent(
        widget.contact.id,
        eventName,
        _onRealtimeMessageMutated,
      );
    }
  }

  void _onRealtimeMessageCreated(RealtimeEvent event) {
    final payload = event.data;
    final conversationId = extractConversationId(payload);
    if (conversationId.isNotEmpty && conversationId != widget.contact.id) {
      return;
    }

    final messageRaw = payload['message'];
    if (messageRaw is! Map<String, dynamic>) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final currentUserId = resolveCurrentUserId(authProvider.user);
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
    if (message.id.isEmpty || !mounted) {
      return;
    }

    final shouldSkipSelfPlaceholder =
        message.isMe &&
        message.text.trim().isEmpty &&
        message.attachments.isEmpty &&
        _messages.any(
          (item) =>
              item.isMe &&
              item.mediaSendState != MediaSendState.sent &&
              item.localMediaPath != null,
        );
    if (shouldSkipSelfPlaceholder) {
      if (looksLikeImageMessage(normalized)) {
        _refreshMessageById(message.id);
      }
      return;
    }

    _upsertMessage(
      message,
      scrollToBottom: true,
      replaceTemporaryText: message.isMe && message.text.trim().isNotEmpty,
    );

    if (looksLikeImageMessage(normalized) && message.attachments.isEmpty) {
      _refreshMessageById(message.id);
    }
  }

  void _onRealtimeMessageMutated(RealtimeEvent event) {
    final payload = event.data;
    final conversationId = extractConversationId(payload);
    if (conversationId.isNotEmpty && conversationId != widget.contact.id) {
      return;
    }

    final messageRaw = payload['message'];
    final messageId =
        (messageRaw is Map<String, dynamic>
                ? messageRaw['id']
                : null) ??
            payload['message_id'] ??
            payload['id'];
    final normalizedMessageId = (messageId ?? '').toString();
    if (normalizedMessageId.isEmpty) {
      return;
    }
    _refreshMessageById(normalizedMessageId);
  }

  void _onRealtimeMessageDeletedForEveryone(RealtimeEvent event) {
    final payload = event.data;
    final conversationId = extractConversationId(payload);
    if (conversationId.isNotEmpty && conversationId != widget.contact.id) {
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
      _messages[index] = current.copyWith(
        text: 'Tin nhan da duoc xoa',
        attachments: const [],
        reactionSummary: const [],
        myReactionCode: null,
      );
    });
    _persistMessages();
  }

  void _onRealtimeTypingUpdated(RealtimeEvent event) {
    final payload = event.data;
    final conversationId = extractConversationId(payload);
    if (conversationId.isNotEmpty && conversationId != widget.contact.id) {
      return;
    }
    if (!mounted) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final currentUserId = resolveCurrentUserId(authProvider.user);
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

  // ---------------------------------------------------------------------------
  // Send text message
  // ---------------------------------------------------------------------------

  Future<void> _handleSend(String text) async {
    if (widget.contact.id.isEmpty) {
      _showSnackBar('Khong tim thay conversation id');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final userId = resolveCurrentUserId(authProvider.user);

    final optimistic = MessageItem(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isMe: true,
      time: DateTime.now().toIso8601String(),
    );

    _upsertMessage(optimistic, scrollToBottom: true);
    setState(() {
      _sending = true;
    });

    try {
      final response = await _sendMessageWithFallback(authProvider, text);
      final payload = extractMessagePayload(response);
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

        _replaceMessage(optimistic.id, serverMessage, scrollToBottom: true);
      }
    } on ApiException catch (e) {
      _removeMessageById(optimistic.id);
      _showSnackBar('Gui tin nhan that bai: ${readableApiError(e)}');
    } catch (e) {
      _removeMessageById(optimistic.id);
      _showSnackBar('Gui tin nhan that bai: $e');
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

  // ---------------------------------------------------------------------------
  // Send image message
  // ---------------------------------------------------------------------------

  Future<void> _handlePickPhoto() async {
    if (!await _ensurePhotoPermission()) {
      return;
    }
    await _pickAndSendImage(ImageSource.gallery);
  }

  Future<void> _handleOpenCamera() async {
    if (!await _ensureCameraPermission()) {
      return;
    }
    await _pickAndSendImage(ImageSource.camera);
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(source: source);
      if (!mounted || file == null || file.path.trim().isEmpty) {
        return;
      }
      await _sendImageMessage(file.path);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Khong the mo anh: $e');
    }
  }

  Future<void> _sendImageMessage(
    String localPath, {
    String? existingMessageId,
  }) async {
    if (widget.contact.id.isEmpty) {
      _showSnackBar('Khong tim thay conversation id');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final userId = resolveCurrentUserId(authProvider.user);
    final localMessageId =
        existingMessageId ?? 'temp-media-${DateTime.now().millisecondsSinceEpoch}';

    final optimisticMessage = MessageItem(
      id: localMessageId,
      text: '',
      isMe: true,
      time: DateTime.now().toIso8601String(),
      attachments: [
        MessageAttachmentItem(
          id: 'local-$localMessageId',
          url: '',
          mimeType: guessImageMimeType(localPath),
          localPath: localPath,
        ),
      ],
      mediaSendState: MediaSendState.sending,
    );

    _upsertMessage(optimisticMessage, scrollToBottom: true);

    String serverMessageId = existingMessageId ?? '';
    try {
      if (serverMessageId.isEmpty || serverMessageId.startsWith('temp-')) {
        final createdResponse = await authProvider.api.messages.sendMessage(
          widget.contact.id,
          {'content': '', 'type': 'image'},
        );
        final createdPayload = extractMessagePayload(createdResponse);
        serverMessageId =
            (createdPayload?['id'] ?? extractMessageId(createdResponse))
                .toString();
        if (serverMessageId.isEmpty) {
          throw Exception('Khong nhan duoc message id cho anh');
        }

        final createdMessage = MessageItem(
          id: serverMessageId,
          text: '',
          isMe: true,
          time:
              (createdPayload?['created_at'] ??
                      createdPayload?['createdAt'] ??
                      createdPayload?['time'] ??
                      optimisticMessage.time)
                  .toString(),
          attachments: optimisticMessage.attachments,
          mediaSendState: MediaSendState.sending,
        );
        _replaceMessage(localMessageId, createdMessage, scrollToBottom: true);
      }

      final currentPendingMessage = _messageById(serverMessageId) ?? optimisticMessage;
      final uploadResponse = await authProvider.api.attachments.addAttachment(
        serverMessageId,
        filePath: localPath,
      );
      final resolvedMessage = await _resolveServerMessageAfterUpload(
        authProvider: authProvider,
        userId: userId,
        messageId: serverMessageId,
        uploadResponse: uploadResponse,
        fallbackMessage: currentPendingMessage.copyWith(
          id: serverMessageId,
          mediaSendState: MediaSendState.sent,
        ),
      );

      _upsertMessage(
        resolvedMessage.copyWith(mediaSendState: MediaSendState.sent),
        scrollToBottom: true,
      );
    } on ApiException catch (e) {
      _markMessageUploadFailed(
        messageId: serverMessageId.isNotEmpty ? serverMessageId : localMessageId,
      );
      _showSnackBar('Gui anh that bai: ${readableApiError(e)}');
    } catch (e) {
      _markMessageUploadFailed(
        messageId: serverMessageId.isNotEmpty ? serverMessageId : localMessageId,
      );
      _showSnackBar('Gui anh that bai: $e');
    }
  }

  Future<void> _retryMediaMessage(MessageItem message) async {
    final localPath = message.localMediaPath;
    if (localPath == null || localPath.trim().isEmpty) {
      _showSnackBar('Khong tim thay anh de thu lai');
      return;
    }

    _upsertMessage(
      message.copyWith(mediaSendState: MediaSendState.sending),
      scrollToBottom: false,
    );
    await _sendImageMessage(localPath, existingMessageId: message.id);
  }

  Future<void> _removeLocalMediaMessage(MessageItem message) async {
    _removeMessageById(message.id);
  }

  Future<MessageItem> _resolveServerMessageAfterUpload({
    required AuthProvider authProvider,
    required String userId,
    required String messageId,
    required dynamic uploadResponse,
    required MessageItem fallbackMessage,
  }) async {
    final uploadPayload = extractMessagePayload(uploadResponse);
    if (uploadPayload != null) {
      final parsed = MessageItem.fromJson(uploadPayload, currentUserId: userId);
      if (parsed.id == messageId && parsed.attachments.isNotEmpty) {
        return parsed;
      }
    }

    final refreshed = await _refreshMessageById(messageId);
    if (refreshed != null && refreshed.attachments.isNotEmpty) {
      return refreshed;
    }

    return fallbackMessage;
  }

  // ---------------------------------------------------------------------------
  // Reactions
  // ---------------------------------------------------------------------------

  Future<void> _showReactionPicker(MessageItem message, Offset position) async {
    if (message.id.isEmpty || message.id.startsWith('temp-')) {
      return;
    }

    final selectedReaction = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Reaction picker',
      barrierColor: Colors.black.withValues(alpha: 0.08),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenSize = MediaQuery.of(dialogContext).size;
        const pickerWidth = 300.0;
        const pickerHeight = 72.0;
        final left = (position.dx - (pickerWidth / 2)).clamp(
          12.0,
          screenSize.width - pickerWidth - 12,
        );
        final top = (position.dy - pickerHeight - 18).clamp(
          24.0,
          screenSize.height - pickerHeight - 24,
        );

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                child: ReactionPickerCard(
                  options: reactionOptions,
                  selectedCode: message.myReactionCode,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selectedReaction == null) {
      return;
    }

    await _toggleReaction(message, selectedReaction);
  }

  Future<void> _toggleReaction(
    MessageItem originalMessage,
    String selectedCode,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final currentCode = originalMessage.myReactionCode;
    final nextCode = currentCode == selectedCode ? null : selectedCode;

    _upsertMessage(_applyOptimisticReaction(originalMessage, nextCode));

    try {
      if (currentCode != null && currentCode.isNotEmpty) {
        await authProvider.api.reactions.deleteReaction(
          originalMessage.id,
          payload: {'reaction_code': currentCode},
        );
      }

      if (nextCode != null) {
        await authProvider.api.reactions.addReaction(
          originalMessage.id,
          {'reaction_code': nextCode},
        );
      }

      await _refreshMessageById(originalMessage.id);
      await _refreshMessageReactions(
        originalMessage.id,
        fallbackMyReactionCode: nextCode,
      );
    } on ApiException catch (e) {
      _upsertMessage(originalMessage);
      _showSnackBar('Khong the cap nhat cam xuc: ${readableApiError(e)}');
    } catch (e) {
      _upsertMessage(originalMessage);
      _showSnackBar('Khong the cap nhat cam xuc: $e');
    }
  }

  MessageItem _applyOptimisticReaction(
    MessageItem message,
    String? nextReactionCode,
  ) {
    final counts = <String, MessageReactionSummary>{};
    for (final item in message.reactionSummary) {
      counts[item.reactionCode] = item;
    }

    final currentCode = message.myReactionCode;
    if (currentCode != null && counts.containsKey(currentCode)) {
      final current = counts[currentCode]!;
      final nextCount = current.count - 1;
      if (nextCount <= 0) {
        counts.remove(currentCode);
      } else {
        counts[currentCode] = MessageReactionSummary(
          reactionCode: current.reactionCode,
          count: nextCount,
          reactedByMe: false,
        );
      }
    }

    if (nextReactionCode != null) {
      final existing = counts[nextReactionCode];
      counts[nextReactionCode] = MessageReactionSummary(
        reactionCode: nextReactionCode,
        count: (existing?.count ?? 0) + 1,
        reactedByMe: true,
      );
    }

    final updatedSummary = counts.values.toList(growable: false)
      ..sort((a, b) {
        final orderCompare =
            reactionOrderIndex(a.reactionCode).compareTo(
              reactionOrderIndex(b.reactionCode),
            );
        if (orderCompare != 0) {
          return orderCompare;
        }
        return a.reactionCode.compareTo(b.reactionCode);
      });

    return message.copyWith(
      reactionSummary: updatedSummary,
      myReactionCode: nextReactionCode,
    );
  }

  Future<void> _refreshMessageReactions(
    String messageId, {
    String? fallbackMyReactionCode,
  }) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = resolveCurrentUserId(authProvider.user);
      final response = await authProvider.api.reactions.getReactions(messageId);
      final reactionSource = extractReactionSource(response);
      final summaries = MessageReactionSummary.parseList(
        reactionSource,
        currentUserId: currentUserId,
      );
      final currentMessage = _messageById(messageId);
      if (currentMessage == null) {
        return;
      }

      final myReactionCode =
          MessageReactionSummary.resolveMyReactionCode(summaries) ??
          fallbackMyReactionCode;
      _upsertMessage(
        currentMessage.copyWith(
          reactionSummary: summaries,
          myReactionCode: myReactionCode,
        ),
      );
    } catch (_) {
      // Keep optimistic reaction state if explicit refresh fails.
    }
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  Future<bool> _ensurePhotoPermission() async {
    if (!Platform.isIOS) {
      return true;
    }
    return _requestPermission(
      Permission.photos,
      deniedMessage: 'Mess App cần quyền Photo để chọn ảnh gửi trong chat.',
    );
  }

  Future<bool> _ensureCameraPermission() {
    return _requestPermission(
      Permission.camera,
      deniedMessage: 'Mess App cần quyền Camera để chụp ảnh gửi trong chat.',
    );
  }

  Future<bool> _requestPermission(
    Permission permission, {
    required String deniedMessage,
  }) async {
    var status = await permission.status;
    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isDenied) {
      status = await permission.request();
      if (status.isGranted || status.isLimited) {
        return true;
      }
    }

    _showPermissionSnackBar(deniedMessage);
    return false;
  }

  void _showPermissionSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Cài đặt',
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Contact name resolution
  // ---------------------------------------------------------------------------

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
      final currentUserId = resolveCurrentUserId(authProvider.user);
      final response = await authProvider.api.participants.getParticipants(
        widget.contact.id,
      );
      final participants = extractList(
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
      // Keep fallback name.
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

  String? _avatarUrl() {
    final avatar = widget.contact.avatarUrl;
    if (avatar != null && avatar.trim().isNotEmpty) {
      return avatar;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Message refresh
  // ---------------------------------------------------------------------------

  Future<MessageItem?> _refreshMessageById(String messageId) async {
    if (messageId.isEmpty) {
      return null;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = resolveCurrentUserId(authProvider.user);
      final response = await authProvider.api.messages.getMessageById(messageId);
      final payload = extractMessagePayload(response);
      if (payload == null) {
        return null;
      }

      var refreshed = MessageItem.fromJson(payload, currentUserId: userId);
      final existing = _messageById(messageId);
      if (existing != null && refreshed.attachments.isEmpty) {
        refreshed = refreshed.copyWith(attachments: existing.attachments);
      }
      if (existing != null && refreshed.reactionSummary.isEmpty) {
        refreshed = refreshed.copyWith(
          reactionSummary: existing.reactionSummary,
          myReactionCode: refreshed.myReactionCode ?? existing.myReactionCode,
        );
      }

      _upsertMessage(refreshed);
      return refreshed;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Message list management
  // ---------------------------------------------------------------------------

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
    final localOnlyMessages = <MessageItem>[];

    for (final item in current) {
      if (item.id.startsWith('temp-')) {
        localOnlyMessages.add(item);
      } else if (item.id.isNotEmpty) {
        byId[item.id] = item;
      }
    }

    for (final item in incoming) {
      if (item.id.isNotEmpty) {
        final existing = byId[item.id];
        if (existing != null &&
            item.attachments.isEmpty &&
            existing.attachments.isNotEmpty) {
          byId[item.id] = item.copyWith(
            attachments: existing.attachments,
            reactionSummary: item.reactionSummary.isEmpty
                ? existing.reactionSummary
                : item.reactionSummary,
            myReactionCode: item.myReactionCode ?? existing.myReactionCode,
          );
        } else {
          byId[item.id] = item;
        }
      }
    }

    return _sortMessagesByTime([...byId.values, ...localOnlyMessages]);
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

  MessageItem? _messageById(String messageId) {
    try {
      return _messages.firstWhere((item) => item.id == messageId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistMessages() async {
    await _cacheService.saveMessages(widget.contact.id, _messages);
  }

  void _upsertMessage(
    MessageItem message, {
    bool scrollToBottom = false,
    bool replaceTemporaryText = false,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      final next = List<MessageItem>.from(_messages);
      if (replaceTemporaryText) {
        next.removeWhere(
          (item) =>
              item.id.startsWith('temp-') &&
              item.text.trim().isNotEmpty &&
              item.text.trim() == message.text.trim(),
        );
      }

      final index = next.indexWhere((item) => item.id == message.id);
      if (index >= 0) {
        next[index] = message;
      } else {
        next.add(message);
      }
      _messages = _sortMessagesByTime(next);
    });

    _persistMessages();
    if (scrollToBottom) {
      _scrollToBottom();
    }
  }

  void _replaceMessage(
    String oldMessageId,
    MessageItem replacement, {
    bool scrollToBottom = false,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      final next = List<MessageItem>.from(_messages)
        ..removeWhere((item) => item.id == oldMessageId);
      final existingIndex = next.indexWhere((item) => item.id == replacement.id);
      if (existingIndex >= 0) {
        next[existingIndex] = replacement;
      } else {
        next.add(replacement);
      }
      _messages = _sortMessagesByTime(next);
    });

    _persistMessages();
    if (scrollToBottom) {
      _scrollToBottom();
    }
  }

  void _removeMessageById(String messageId) {
    if (!mounted) {
      return;
    }

    setState(() {
      _messages = _sortMessagesByTime(
        _messages.where((item) => item.id != messageId).toList(),
      );
    });
    _persistMessages();
  }

  void _markMessageUploadFailed({required String messageId}) {
    final message = _messageById(messageId);
    if (message == null) {
      return;
    }
    _upsertMessage(message.copyWith(mediaSendState: MediaSendState.failed));
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showComingSoon(String label) {
    _showSnackBar('$label đang được phát triển');
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
          ConversationHeader(
            contactName: _contactName,
            avatarUrl: _avatarUrl(),
            initials: _displayInitials(),
            embedded: widget.embedded,
            onBack: widget.onBack,
            onAction: _showComingSoon,
          ),
          Expanded(
            child: MessageList(
              messages: _messages,
              scrollController: _scrollController,
              embedded: widget.embedded,
              sending: _sending,
              lastOwnMessageId: lastOwnMessage.id,
              peerInitials: _displayInitials(),
              peerAvatarUrl: _avatarUrl(),
              onLongPressMessage: _showReactionPicker,
              onRetryMedia: _retryMediaMessage,
              onRemoveMedia: _removeLocalMediaMessage,
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
                  ConversationAvatar(
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
            onPickPhoto: _handlePickPhoto,
            onOpenCamera: _handleOpenCamera,
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
