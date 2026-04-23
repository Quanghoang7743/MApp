import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class RealtimeEvent {
  RealtimeEvent({
    required this.channelName,
    required this.eventName,
    required this.data,
  });

  final String channelName;
  final String eventName;
  final Map<String, dynamic> data;
}

typedef RealtimeHandler = void Function(RealtimeEvent event);

class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  final Map<String, List<RealtimeHandler>> _handlers = {};

  Future<String?> Function()? _tokenProvider;
  String _authEndpoint = '';

  bool _initialized = false;
  bool _connected = false;

  Future<void> ensureConnected({
    required String apiKey,
    required String cluster,
    required bool useTLS,
    required String authEndpoint,
    required Future<String?> Function() tokenProvider,
  }) async {
    if (apiKey.trim().isEmpty) {
      return;
    }

    _tokenProvider = tokenProvider;
    _authEndpoint = authEndpoint;

    if (!_initialized) {
      await _pusher.init(
        apiKey: apiKey,
        cluster: cluster,
        useTLS: useTLS,
        onConnectionStateChange: (currentState, previousState) {
          _connected = currentState == 'CONNECTED';
        },
        onEvent: (event) {
          final payload = _parseEventData(event.data);
          final key = '${event.channelName}|${event.eventName}';
          final callbacks = _handlers[key];
          if (callbacks == null || callbacks.isEmpty) {
            return;
          }

          final wrapper = RealtimeEvent(
            channelName: event.channelName,
            eventName: event.eventName,
            data: payload,
          );

          for (final handler in List<RealtimeHandler>.from(callbacks)) {
            handler(wrapper);
          }
        },
        onAuthorizer: _authorizer,
      );
      _initialized = true;
    }

    if (!_connected) {
      await _pusher.connect();
    }
  }

  Future<dynamic> _authorizer(
    String channelName,
    String socketId,
    dynamic options,
  ) async {
    final token = await _tokenProvider?.call();
    final response = await http.post(
      Uri.parse(_authEndpoint),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'socket_id': socketId, 'channel_name': channelName}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Realtime auth failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw Exception('Invalid realtime auth payload');
  }

  Future<void> subscribeConversation(String conversationId) async {
    if (conversationId.isEmpty || !_initialized) {
      return;
    }
    await _pusher.subscribe(channelName: _conversationChannel(conversationId));
  }

  Future<void> unsubscribeConversation(String conversationId) async {
    if (conversationId.isEmpty || !_initialized) {
      return;
    }
    await _pusher.unsubscribe(
      channelName: _conversationChannel(conversationId),
    );
  }

  void bindConversationEvent(
    String conversationId,
    String eventName,
    RealtimeHandler handler,
  ) {
    final key = '${_conversationChannel(conversationId)}|$eventName';
    final list = _handlers[key] ?? <RealtimeHandler>[];
    list.add(handler);
    _handlers[key] = list;
  }

  void unbindConversationEvent(
    String conversationId,
    String eventName,
    RealtimeHandler handler,
  ) {
    final key = '${_conversationChannel(conversationId)}|$eventName';
    final list = _handlers[key];
    if (list == null) {
      return;
    }
    list.remove(handler);
    if (list.isEmpty) {
      _handlers.remove(key);
    }
  }

  String _conversationChannel(String conversationId) {
    return 'private-conversation.$conversationId';
  }

  Map<String, dynamic> _parseEventData(dynamic data) {
    if (data == null) {
      return {};
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        return {};
      }
    }
    return {};
  }
}
