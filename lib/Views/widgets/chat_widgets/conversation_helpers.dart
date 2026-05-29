import '../../../services/api_client.dart';

/// Extracts the conversation ID from a realtime event payload.
String extractConversationId(Map<String, dynamic> payload) {
  final direct = payload['conversation_id'] ?? payload['conversationId'];
  if (direct != null && direct.toString().isNotEmpty) {
    return direct.toString();
  }

  final message = payload['message'];
  if (message is Map<String, dynamic>) {
    final messageConversationId =
        message['conversation_id'] ?? message['conversationId'];
    if (messageConversationId != null &&
        messageConversationId.toString().isNotEmpty) {
      return messageConversationId.toString();
    }
  }

  return '';
}

/// Extracts a [Map] message payload from an API response.
Map<String, dynamic>? extractMessagePayload(dynamic response) {
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

/// Extracts the message `id` from an API response.
dynamic extractMessageId(dynamic response) {
  if (response is Map<String, dynamic>) {
    if (response['id'] != null) {
      return response['id'];
    }
    final data = response['data'];
    if (data is Map<String, dynamic> && data['id'] != null) {
      return data['id'];
    }
  }
  return null;
}

/// Extracts a [List] from an API response that may wrap data in nested maps.
List<dynamic> extractList(dynamic response) {
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

/// Extracts the raw reaction source from an API response.
dynamic extractReactionSource(dynamic response) {
  if (response is Map<String, dynamic>) {
    if (response['data'] != null) {
      return response['data'];
    }
    if (response['reactions'] != null) {
      return response['reactions'];
    }
  }
  return response;
}

/// Resolves the current user ID from various user map shapes.
String resolveCurrentUserId(Map<String, dynamic>? user) {
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

/// Formats a raw time string into `HH:mm`.
String formatTime(String raw) {
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

/// Returns `true` if the payload's type field indicates an image message.
bool looksLikeImageMessage(Map<String, dynamic> payload) {
  final type =
      (payload['type'] ??
              payload['message_type'] ??
              payload['messageType'])
          ?.toString()
          .toLowerCase();
  return type == 'image';
}

/// Returns a human-readable error message from an [ApiException].
String readableApiError(ApiException error) {
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

/// Guesses a MIME type from a file path extension.
String guessImageMimeType(String path) {
  final normalized = path.toLowerCase();
  if (normalized.endsWith('.png')) {
    return 'image/png';
  }
  if (normalized.endsWith('.gif')) {
    return 'image/gif';
  }
  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }
  if (normalized.endsWith('.heic')) {
    return 'image/heic';
  }
  return 'image/jpeg';
}
