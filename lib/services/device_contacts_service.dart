import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/device_contact_phone.dart';

enum ContactPermissionState {
  unsupported,
  notDetermined,
  denied,
  permanentlyDenied,
  restricted,
  granted,
  limited,
}

class DeviceContactsService {
  bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<ContactPermissionState> getPermissionStatus() async {
    if (!isSupportedPlatform) {
      return ContactPermissionState.unsupported;
    }

    final status = await FlutterContacts.permissions.check(PermissionType.read);
    return _mapPermissionStatus(status);
  }

  Future<ContactPermissionState> requestPermission() async {
    if (!isSupportedPlatform) {
      return ContactPermissionState.unsupported;
    }

    final status = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    return _mapPermissionStatus(status);
  }

  Future<bool> openSettings() async {
    if (!isSupportedPlatform) {
      return false;
    }

    await FlutterContacts.permissions.openSettings();
    return true;
  }

  Future<List<DeviceContactPhone>> getAllPhoneContacts() async {
    if (!isSupportedPlatform) {
      return const [];
    }

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    final uniqueContacts = <String, DeviceContactPhone>{};

    for (final contact in contacts) {
      final displayName = (contact.displayName ?? '').trim();
      final fallbackName = displayName.isEmpty
          ? 'Liên hệ chưa đặt tên'
          : displayName;

      for (final phone in contact.phones) {
        final rawPhone = phone.number.trim();
        final normalizedPhone = normalizePhone(rawPhone);
        if (normalizedPhone.isEmpty ||
            uniqueContacts.containsKey(normalizedPhone)) {
          continue;
        }

        uniqueContacts[normalizedPhone] = DeviceContactPhone(
          displayName: fallbackName,
          rawPhone: rawPhone,
          normalizedPhone: normalizedPhone,
        );
      }
    }

    final result = uniqueContacts.values.toList()
      ..sort((a, b) {
        final nameCompare = a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
        if (nameCompare != 0) {
          return nameCompare;
        }
        return a.normalizedPhone.compareTo(b.normalizedPhone);
      });

    return result;
  }

  String normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return '';
    }

    if (digits.startsWith('84')) {
      digits = digits.substring(2);
    }

    while (digits.startsWith('0') && digits.length > 9) {
      digits = digits.substring(1);
    }

    if (digits.length < 9 || digits.length > 11) {
      return '';
    }

    return digits;
  }

  String phoneForLookup(String normalizedPhone) {
    if (normalizedPhone.isEmpty) {
      return '';
    }
    return normalizedPhone.startsWith('0')
        ? normalizedPhone
        : '0$normalizedPhone';
  }

  ContactPermissionState _mapPermissionStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return ContactPermissionState.granted;
      case PermissionStatus.limited:
        return ContactPermissionState.limited;
      case PermissionStatus.denied:
        return ContactPermissionState.denied;
      case PermissionStatus.permanentlyDenied:
        return ContactPermissionState.permanentlyDenied;
      case PermissionStatus.restricted:
        return ContactPermissionState.restricted;
      case PermissionStatus.notDetermined:
        return ContactPermissionState.notDetermined;
    }
  }
}
