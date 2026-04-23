import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_services.dart';

class FriendProvider with ChangeNotifier {
  ApiServices? _api;

  Map<String, dynamic>? resolvedUser;
  List<Map<String, dynamic>> incomingRequests = [];
  List<Map<String, dynamic>> outgoingRequests = [];

  bool isResolving = false;
  bool isSendingRequest = false;
  bool isLoadingIncoming = false;
  bool isLoadingOutgoing = false;
  bool isProcessingRequest = false;

  String? errorMessage;

  void bindApi(ApiServices api) {
    _api = api;
  }

  Future<void> resolveByPhone(String phoneNumber) async {
    if (_api == null) {
      errorMessage = 'Auth chua san sang';
      notifyListeners();
      return;
    }

    isResolving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _api!.friends.resolveByPhone(
        phoneNumber: phoneNumber,
      );
      resolvedUser = _extractUser(response);
      if (resolvedUser == null) {
        errorMessage = 'Khong tim thay nguoi dung';
      }
    } on ApiException catch (e) {
      errorMessage = _readableApiError(e);
      resolvedUser = null;
    } catch (e) {
      errorMessage = 'Loi ket noi: $e';
      resolvedUser = null;
    } finally {
      isResolving = false;
      notifyListeners();
    }
  }

  Future<bool> sendFriendRequest({required String receiverId}) async {
    if (_api == null) {
      errorMessage = 'Auth chua san sang';
      notifyListeners();
      return false;
    }

    isSendingRequest = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api!.friends.sendFriendRequest({'receiver_id': receiverId});
      await fetchOutgoingRequests();
      return true;
    } on ApiException catch (e) {
      errorMessage = _readableApiError(e);
      return false;
    } catch (e) {
      errorMessage = 'Loi ket noi: $e';
      return false;
    } finally {
      isSendingRequest = false;
      notifyListeners();
    }
  }

  Future<void> fetchIncomingRequests() async {
    if (_api == null) {
      return;
    }

    isLoadingIncoming = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _api!.friends.getIncomingFriendRequests();
      incomingRequests = _extractList(
        response,
      ).whereType<Map<String, dynamic>>().toList();
    } on ApiException catch (e) {
      errorMessage = _readableApiError(e);
    } catch (e) {
      errorMessage = 'Loi ket noi: $e';
    } finally {
      isLoadingIncoming = false;
      notifyListeners();
    }
  }

  Future<void> fetchOutgoingRequests() async {
    if (_api == null) {
      return;
    }

    isLoadingOutgoing = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _api!.friends.getOutgoingFriendRequests();
      outgoingRequests = _extractList(
        response,
      ).whereType<Map<String, dynamic>>().toList();
    } on ApiException catch (e) {
      errorMessage = _readableApiError(e);
    } catch (e) {
      errorMessage = 'Loi ket noi: $e';
    } finally {
      isLoadingOutgoing = false;
      notifyListeners();
    }
  }

  Future<bool> acceptRequest(String requestId) async {
    return _processRequestAction(() async {
      await _api!.friends.acceptFriendRequest(requestId);
      await fetchIncomingRequests();
    });
  }

  Future<bool> rejectRequest(String requestId) async {
    return _processRequestAction(() async {
      await _api!.friends.rejectFriendRequest(requestId);
      await fetchIncomingRequests();
    });
  }

  Future<bool> cancelRequest(String requestId) async {
    return _processRequestAction(() async {
      await _api!.friends.cancelFriendRequest(requestId);
      await fetchOutgoingRequests();
    });
  }

  Future<bool> unfriend(String userId) async {
    return _processRequestAction(() async {
      await _api!.friends.unfriend(userId);
    });
  }

  Future<bool> _processRequestAction(Future<void> Function() action) async {
    if (_api == null) {
      errorMessage = 'Auth chua san sang';
      notifyListeners();
      return false;
    }

    isProcessingRequest = true;
    errorMessage = null;
    notifyListeners();

    try {
      await action();
      return true;
    } on ApiException catch (e) {
      errorMessage = _readableApiError(e);
      return false;
    } catch (e) {
      errorMessage = 'Loi ket noi: $e';
      return false;
    } finally {
      isProcessingRequest = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? _extractUser(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final user = data['user'];
        if (user is Map<String, dynamic>) {
          return user;
        }
        return data;
      }

      final user = response['user'];
      if (user is Map<String, dynamic>) {
        return user;
      }

      return response;
    }
    return null;
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) {
      return response;
    }

    if (response is Map<String, dynamic>) {
      for (final key in const [
        'data',
        'items',
        'results',
        'incoming',
        'outgoing',
      ]) {
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
    }

    return const [];
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
}
