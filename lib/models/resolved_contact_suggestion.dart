import 'device_contact_phone.dart';

enum ResolvedContactSuggestionStatus {
  canInvite,
  alreadyFriend,
  requestSent,
  requestReceived,
  notFound,
  lookupFailed,
}

class ResolvedContactSuggestion {
  const ResolvedContactSuggestion({
    required this.contact,
    required this.status,
    this.resolvedUser,
  });

  final DeviceContactPhone contact;
  final ResolvedContactSuggestionStatus status;
  final Map<String, dynamic>? resolvedUser;
}
