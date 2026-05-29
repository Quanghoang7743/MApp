import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_contact_phone.dart';
import '../models/resolved_contact_suggestion.dart';
import '../services/api_client.dart';
import '../services/api_services.dart';
import '../services/device_contacts_service.dart';

class ContactSyncProvider with ChangeNotifier {
  ContactSyncProvider({
    DeviceContactsService? contactsService,
    DateTime Function()? nowProvider,
  }) : _contactsService = contactsService ?? DeviceContactsService(),
       _nowProvider = nowProvider ?? DateTime.now;

  static const _prePermissionPromptHandledKey =
      'contacts_pre_permission_prompt_handled_v1';
  static const _lookupCacheKey = 'contacts_lookup_cache_v1';
  static const _lastSyncedAtKey = 'contacts_last_synced_at_v1';
  static const _lookupCacheTtl = Duration(hours: 24);
  static const _maxConcurrentLookups = 4;

  final DeviceContactsService _contactsService;
  final DateTime Function() _nowProvider;

  ApiServices? _api;
  bool _isInitialized = false;
  int _syncGeneration = 0;

  bool isInitializing = false;
  bool hasHandledPrePermissionPrompt = false;
  bool isLoadingContacts = false;
  bool isSyncingSuggestions = false;
  ContactPermissionState permissionState = ContactPermissionState.notDetermined;
  String? lookupError;
  DateTime? lastSyncedAt;

  List<DeviceContactPhone> contacts = [];
  List<ResolvedContactSuggestion> suggestions = [];

  void bindApi(ApiServices api) {
    _api = api;
  }

  bool get isSupportedPlatform => _contactsService.isSupportedPlatform;

  bool get hasContactsAccess =>
      permissionState == ContactPermissionState.granted ||
      permissionState == ContactPermissionState.limited;

  bool get shouldShowPrePermissionPrompt =>
      isSupportedPlatform &&
      _isInitialized &&
      !hasHandledPrePermissionPrompt &&
      permissionState == ContactPermissionState.notDetermined;

  bool get shouldShowOpenSettings =>
      permissionState == ContactPermissionState.permanentlyDenied ||
      permissionState == ContactPermissionState.restricted;

  Future<void> initialize() async {
    if (_isInitialized || isInitializing) {
      return;
    }

    isInitializing = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    hasHandledPrePermissionPrompt =
        prefs.getBool(_prePermissionPromptHandledKey) ?? false;
    lastSyncedAt = _parseDateTime(prefs.getString(_lastSyncedAtKey));
    permissionState = await _readPermissionStatus();

    _isInitialized = true;
    isInitializing = false;
    notifyListeners();
  }

  Future<void> markPrePermissionPromptHandled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prePermissionPromptHandledKey, true);
    hasHandledPrePermissionPrompt = true;
    notifyListeners();
  }

  Future<ContactPermissionState> refreshPermissionStatus() async {
    permissionState = await _readPermissionStatus();
    notifyListeners();
    return permissionState;
  }

  Future<bool> requestContactsAccess() async {
    await initialize();
    if (!isSupportedPlatform) {
      permissionState = ContactPermissionState.unsupported;
      notifyListeners();
      return false;
    }

    permissionState = await _contactsService.requestPermission();
    notifyListeners();
    return hasContactsAccess;
  }

  Future<void> loadAndResolveContacts({bool forceRefresh = false}) async {
    await initialize();
    if (_api == null) {
      lookupError = 'Auth chua san sang';
      notifyListeners();
      return;
    }

    if (!hasContactsAccess) {
      lookupError = 'Chua duoc cap quyen danh ba';
      notifyListeners();
      return;
    }

    final generation = ++_syncGeneration;
    lookupError = null;
    isLoadingContacts = true;
    isSyncingSuggestions = true;
    notifyListeners();

    try {
      final loadedContacts = await _contactsService.getAllPhoneContacts();
      if (!_isSyncCurrent(generation)) {
        return;
      }

      contacts = loadedContacts;
      isLoadingContacts = false;
      notifyListeners();

      final relationshipSnapshot = await _loadRelationshipSnapshot();
      if (!_isSyncCurrent(generation)) {
        return;
      }

      final suggestionsByPhone = <String, ResolvedContactSuggestion>{};
      final cache = await _readLookupCache();

      for (var i = 0; i < loadedContacts.length; i += _maxConcurrentLookups) {
        final end = math.min(i + _maxConcurrentLookups, loadedContacts.length);
        final chunk = loadedContacts.sublist(i, end);

        final resolvedChunk = await Future.wait(
          chunk.map(
            (contact) => _resolveSuggestion(
              contact: contact,
              cache: cache,
              relationshipSnapshot: relationshipSnapshot,
              forceRefresh: forceRefresh,
            ),
          ),
        );

        if (!_isSyncCurrent(generation)) {
          return;
        }

        for (final suggestion in resolvedChunk) {
          suggestionsByPhone[suggestion.contact.normalizedPhone] = suggestion;
        }

        suggestions = loadedContacts
            .where(
              (contact) =>
                  suggestionsByPhone.containsKey(contact.normalizedPhone),
            )
            .map((contact) => suggestionsByPhone[contact.normalizedPhone]!)
            .toList(growable: false);
        notifyListeners();
      }

      suggestions = loadedContacts
          .map((contact) => suggestionsByPhone[contact.normalizedPhone])
          .whereType<ResolvedContactSuggestion>()
          .toList(growable: false);
      lastSyncedAt = _now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncedAtKey, lastSyncedAt!.toIso8601String());
    } catch (e) {
      lookupError = 'Khong the dong bo danh ba: $e';
    } finally {
      if (_isSyncCurrent(generation)) {
        isLoadingContacts = false;
        isSyncingSuggestions = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() async {
    await loadAndResolveContacts(forceRefresh: true);
  }

  void cancelOngoingSync() {
    _syncGeneration++;
    isLoadingContacts = false;
    isSyncingSuggestions = false;
    notifyListeners();
  }

  Future<bool> openSystemSettings() {
    return _contactsService.openSettings();
  }

  Future<ContactPermissionState> _readPermissionStatus() async {
    if (!isSupportedPlatform) {
      return ContactPermissionState.unsupported;
    }
    return _contactsService.getPermissionStatus();
  }

  bool _isSyncCurrent(int generation) => generation == _syncGeneration;

  Future<ResolvedContactSuggestion> _resolveSuggestion({
    required DeviceContactPhone contact,
    required Map<String, _LookupCacheEntry> cache,
    required _RelationshipSnapshot relationshipSnapshot,
    required bool forceRefresh,
  }) async {
    final cached = cache[contact.normalizedPhone];
    final cachedIsFresh =
        cached != null && _now().difference(cached.savedAt) <= _lookupCacheTtl;

    if (!forceRefresh && cachedIsFresh) {
      return _buildSuggestion(
        contact: contact,
        resolvedUser: cached.resolvedUser,
        relationshipSnapshot: relationshipSnapshot,
        fromLookupError: false,
      );
    }

    try {
      final response = await _api!.friends.resolveByPhone(
        phoneNumber: _contactsService.phoneForLookup(contact.normalizedPhone),
      );
      final resolvedUser = _extractUser(response);
      await _saveLookupCache(contact.normalizedPhone, resolvedUser);
      return _buildSuggestion(
        contact: contact,
        resolvedUser: resolvedUser,
        relationshipSnapshot: relationshipSnapshot,
        fromLookupError: false,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        await _saveLookupCache(contact.normalizedPhone, null);
        return _buildSuggestion(
          contact: contact,
          resolvedUser: null,
          relationshipSnapshot: relationshipSnapshot,
          fromLookupError: false,
        );
      }

      return _buildSuggestion(
        contact: contact,
        resolvedUser: cached?.resolvedUser,
        relationshipSnapshot: relationshipSnapshot,
        fromLookupError: true,
      );
    } catch (_) {
      return _buildSuggestion(
        contact: contact,
        resolvedUser: cached?.resolvedUser,
        relationshipSnapshot: relationshipSnapshot,
        fromLookupError: true,
      );
    }
  }

  ResolvedContactSuggestion _buildSuggestion({
    required DeviceContactPhone contact,
    required Map<String, dynamic>? resolvedUser,
    required _RelationshipSnapshot relationshipSnapshot,
    required bool fromLookupError,
  }) {
    final userId = _resolveUserId(resolvedUser);

    if (fromLookupError && resolvedUser == null) {
      return ResolvedContactSuggestion(
        contact: contact,
        status: ResolvedContactSuggestionStatus.lookupFailed,
      );
    }

    if (resolvedUser == null || userId.isEmpty) {
      return ResolvedContactSuggestion(
        contact: contact,
        status: ResolvedContactSuggestionStatus.notFound,
      );
    }

    if (relationshipSnapshot.friendUserIds.contains(userId)) {
      return ResolvedContactSuggestion(
        contact: contact,
        resolvedUser: resolvedUser,
        status: ResolvedContactSuggestionStatus.alreadyFriend,
      );
    }

    if (relationshipSnapshot.outgoingRequestUserIds.contains(userId)) {
      return ResolvedContactSuggestion(
        contact: contact,
        resolvedUser: resolvedUser,
        status: ResolvedContactSuggestionStatus.requestSent,
      );
    }

    if (relationshipSnapshot.incomingRequestUserIds.contains(userId)) {
      return ResolvedContactSuggestion(
        contact: contact,
        resolvedUser: resolvedUser,
        status: ResolvedContactSuggestionStatus.requestReceived,
      );
    }

    return ResolvedContactSuggestion(
      contact: contact,
      resolvedUser: resolvedUser,
      status: ResolvedContactSuggestionStatus.canInvite,
    );
  }

  Future<_RelationshipSnapshot> _loadRelationshipSnapshot() async {
    if (_api == null) {
      return const _RelationshipSnapshot();
    }

    final friendUserIds = <String>{};
    final outgoingRequestUserIds = <String>{};
    final incomingRequestUserIds = <String>{};

    try {
      final friendsResponse = await _api!.friends.getFriends();
      for (final item in _extractList(friendsResponse)) {
        final normalized = _normalizeFriendItem(item);
        final friendUserId = _resolveFriendUserId(normalized);
        if (friendUserId.isNotEmpty) {
          friendUserIds.add(friendUserId);
        }
      }
    } catch (_) {}

    try {
      final outgoingResponse = await _api!.friends.getOutgoingFriendRequests();
      for (final item in _extractList(outgoingResponse)) {
        final receiverId = _resolveRequestUserId(
          item,
          directKeys: const ['receiver_id', 'friend_id', 'user_id'],
          nestedKeys: const ['receiver', 'user', 'friend'],
        );
        if (receiverId.isNotEmpty) {
          outgoingRequestUserIds.add(receiverId);
        }
      }
    } catch (_) {}

    try {
      final incomingResponse = await _api!.friends.getIncomingFriendRequests();
      for (final item in _extractList(incomingResponse)) {
        final senderId = _resolveRequestUserId(
          item,
          directKeys: const ['sender_id', 'friend_id', 'user_id'],
          nestedKeys: const ['sender', 'user', 'friend'],
        );
        if (senderId.isNotEmpty) {
          incomingRequestUserIds.add(senderId);
        }
      }
    } catch (_) {}

    return _RelationshipSnapshot(
      friendUserIds: friendUserIds,
      outgoingRequestUserIds: outgoingRequestUserIds,
      incomingRequestUserIds: incomingRequestUserIds,
    );
  }

  Future<Map<String, _LookupCacheEntry>> _readLookupCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lookupCacheKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return {};
      }

      final result = <String, _LookupCacheEntry>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) {
          continue;
        }

        final savedAt = _parseDateTime(value['savedAt']);
        if (savedAt == null) {
          continue;
        }

        final resolvedUser = value['resolvedUser'];
        result[entry.key] = _LookupCacheEntry(
          savedAt: savedAt,
          resolvedUser: resolvedUser is Map<String, dynamic>
              ? resolvedUser
              : null,
        );
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLookupCache(
    String normalizedPhone,
    Map<String, dynamic>? resolvedUser,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await _readLookupCache();
    current[normalizedPhone] = _LookupCacheEntry(
      savedAt: _now(),
      resolvedUser: resolvedUser,
    );

    final encoded = <String, dynamic>{
      for (final entry in current.entries)
        entry.key: {
          'savedAt': entry.value.savedAt.toIso8601String(),
          'resolvedUser': entry.value.resolvedUser,
        },
    };

    await prefs.setString(_lookupCacheKey, jsonEncode(encoded));
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) {
      return response;
    }

    if (response is Map<String, dynamic>) {
      for (final key in const [
        'data',
        'friends',
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

  String _resolveFriendUserId(Map<String, dynamic>? friend) {
    if (friend == null) {
      return '';
    }

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

  String _resolveRequestUserId(
    dynamic request, {
    required List<String> directKeys,
    required List<String> nestedKeys,
  }) {
    if (request is! Map<String, dynamic>) {
      return '';
    }

    for (final key in directKeys) {
      final value = request[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }

    for (final key in nestedKeys) {
      final nested = request[key];
      if (nested is Map<String, dynamic>) {
        final nestedId = nested['id'] ?? nested['user_id'];
        if (nestedId != null && nestedId.toString().isNotEmpty) {
          return nestedId.toString();
        }
      }
    }

    return '';
  }

  String _resolveUserId(Map<String, dynamic>? user) {
    if (user == null) {
      return '';
    }

    final id = user['id'] ?? user['user_id'];
    if (id != null && id.toString().isNotEmpty) {
      return id.toString();
    }

    final nestedUser = user['user'];
    if (nestedUser is Map<String, dynamic>) {
      final nestedId = nestedUser['id'] ?? nestedUser['user_id'];
      if (nestedId != null && nestedId.toString().isNotEmpty) {
        return nestedId.toString();
      }
    }

    return '';
  }

  DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  DateTime _now() => _nowProvider().toUtc();
}

class _LookupCacheEntry {
  const _LookupCacheEntry({required this.savedAt, required this.resolvedUser});

  final DateTime savedAt;
  final Map<String, dynamic>? resolvedUser;
}

class _RelationshipSnapshot {
  const _RelationshipSnapshot({
    this.friendUserIds = const <String>{},
    this.outgoingRequestUserIds = const <String>{},
    this.incomingRequestUserIds = const <String>{},
  });

  final Set<String> friendUserIds;
  final Set<String> outgoingRequestUserIds;
  final Set<String> incomingRequestUserIds;
}
