import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'firebase_settings_service.dart';

/// Persists profile data per authenticated user (UID / backend user id).
class ProfileService {
  ProfileService._private();

  static final ProfileService instance = ProfileService._private();
  static const String _fallbackStoreKey = 'settings_profile_snapshot';
  static const String _defaultName = 'User';
  static const String _defaultUsername = '@user';

  final ValueNotifier<Uint8List?> avatarBytes = ValueNotifier<Uint8List?>(null);
  final ValueNotifier<IconData?> avatarIcon = ValueNotifier<IconData?>(null);
  final ValueNotifier<String?> photoUrl = ValueNotifier<String?>(null);
  final ValueNotifier<String> name = ValueNotifier<String>(_defaultName);
  final ValueNotifier<String> username = ValueNotifier<String>(_defaultUsername);

  String? _activeUserKey;
  Future<void>? _profileLoadFuture;

  static String storageKeyForUser({required String? userId, String? email}) {
    final normalizedId = (userId ?? '').trim();
    if (normalizedId.isNotEmpty) {
      return 'settings_profile_snapshot_$normalizedId';
    }

    final normalizedEmail =
        (email ?? '').trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    if (normalizedEmail.isNotEmpty) {
      return 'settings_profile_snapshot_$normalizedEmail';
    }

    return 'settings_profile_snapshot_guest';
  }

  Future<String?> _currentUserId() async {
    try {
      final backendUser = await AuthService.getCurrentUser();
      final id = backendUser?['id']?.toString().trim();
      if (id != null && id.isNotEmpty) {
        debugPrint('ProfileService: current authenticated UID => $id');
        return id;
      }
    } catch (error) {
      debugPrint('ProfileService: unable to resolve current UID: $error');
    }
    return null;
  }

  Future<String> _storageKeyForCurrentUser() async {
    try {
      final backendUser = await AuthService.getCurrentUser();
      return storageKeyForUser(
        userId: backendUser?['id']?.toString(),
        email: backendUser?['email']?.toString(),
      );
    } catch (error) {
      debugPrint('ProfileService: unable to resolve current user key: $error');
      return storageKeyForUser(userId: null, email: null);
    }
  }

  /// Clears in-memory avatar state only (used on logout).
  Future<void> clearInMemoryCache() async {
    avatarBytes.value = null;
    avatarIcon.value = null;
    photoUrl.value = null;
    name.value = _defaultName;
    username.value = _defaultUsername;
    _activeUserKey = null;
    debugPrint('ProfileService: cleared in-memory profile cache on logout');
  }

  Future<void> loadForCurrentUser() {
    if (_profileLoadFuture != null) {
      return _profileLoadFuture!;
    }

    _profileLoadFuture = _loadForCurrentUserInternal();
    return _profileLoadFuture!.whenComplete(() {
      _profileLoadFuture = null;
    });
  }

  Future<void> _loadForCurrentUserInternal() async {
    final key = await _storageKeyForCurrentUser();
    final isSameUser = _activeUserKey == key;

    if (!isSameUser) {
      await clearInMemoryCache();
    }

    _activeUserKey = key;
    await loadFromStorage();

    final hasHydratedProfile =
        name.value != _defaultName ||
        username.value != _defaultUsername ||
        photoUrl.value != null ||
        avatarBytes.value != null;

    if (isSameUser && hasHydratedProfile) {
      debugPrint('ProfileService: skipping redundant profile refresh for the same user');
      return;
    }

    unawaited(_loadProfileFromRemote());
  }

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _storageKeyForCurrentUser();
    _activeUserKey = key;
    final raw = prefs.getString(key) ?? prefs.getString(_fallbackStoreKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      debugPrint('ProfileService: loaded profile snapshot key=$key');

      final storedName = (decoded['name'] ?? '').toString().trim();
      final storedUsername = (decoded['username'] ?? '').toString().trim();

      name.value = storedName.isNotEmpty ? storedName : _defaultName;
      username.value = storedUsername.isNotEmpty
          ? (storedUsername.startsWith('@') ? storedUsername : '@$storedUsername')
          : _defaultUsername;

      final storedPhotoUrl = decoded['photoUrl'] as String?;
      if (storedPhotoUrl != null && storedPhotoUrl.trim().isNotEmpty) {
        photoUrl.value = storedPhotoUrl.trim();
        debugPrint('ProfileService: profile image URL loaded from local storage => $storedPhotoUrl');
        if (avatarBytes.value == null) {
          unawaited(_downloadPhotoBytes(storedPhotoUrl.trim()));
        }
      }

      final avatarBase64 = decoded['avatarBytes'] as String?;
      if (avatarBytes.value == null &&
          avatarBase64 != null &&
          avatarBase64.isNotEmpty) {
        avatarBytes.value = base64Decode(avatarBase64);
        debugPrint('ProfileService: profile image loaded from local storage bytes');
      }

      final iconCode = decoded['avatarIcon'] as int?;
      if (iconCode != null) {
        avatarIcon.value = IconData(iconCode, fontFamily: 'MaterialIcons');
      }
    } catch (error) {
      debugPrint('ProfileService: invalid stored profile data ignored: $error');
    }
  }

  Future<void> _loadProfileFromRemote() async {
    final userId = await _currentUserId();
    if (userId == null) return;

    try {
      final remote = await FirebaseSettingsService.loadProfileForUser(userId);
      final profile = remote['profile'] as Map<String, dynamic>?;
      if (profile == null || profile.isEmpty) return;

      final remoteName = (profile['name'] ?? '').toString().trim();
      final remoteUsername = (profile['username'] ?? '').toString().trim();
      final remotePhotoUrl = (profile['photoUrl'] ?? '').toString().trim();

      if (remoteName.isNotEmpty) name.value = remoteName;
      if (remoteUsername.isNotEmpty) {
        username.value = remoteUsername.startsWith('@')
            ? remoteUsername
            : '@$remoteUsername';
      }

      if (remotePhotoUrl.isNotEmpty) {
        photoUrl.value = remotePhotoUrl;
        debugPrint('ProfileService: profile image URL loaded from database => $remotePhotoUrl');
        if (avatarBytes.value == null) {
          unawaited(_downloadPhotoBytes(remotePhotoUrl));
        }
      }

      await saveToStorage();
    } catch (error) {
      debugPrint('ProfileService: remote profile load failed: $error');
    }
  }

  Future<void> _downloadPhotoBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        avatarBytes.value = response.bodyBytes;
        avatarIcon.value = null;
        debugPrint('ProfileService: profile image bytes downloaded from URL');
      }
    } catch (error) {
      debugPrint('ProfileService: failed to download profile image: $error');
    }
  }

  Future<void> saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _storageKeyForCurrentUser();
    _activeUserKey = key;
    debugPrint('ProfileService: saving profile snapshot for key=$key');

    await prefs.setString(
      key,
      jsonEncode({
        'name': name.value,
        'username': username.value,
        'photoUrl': photoUrl.value,
        'avatarBytes': avatarBytes.value != null
            ? base64Encode(avatarBytes.value!)
            : null,
        'avatarIcon': avatarIcon.value?.codePoint,
      }),
    );

    if (photoUrl.value != null && photoUrl.value!.trim().isNotEmpty) {
      debugPrint('ProfileService: profile image URL saved locally => ${photoUrl.value}');
    }
  }

  Future<void> updateProfile({
    Uint8List? bytes,
    IconData? icon,
    String? newName,
    String? newUsername,
    String? newPhotoUrl,
    bool clearAvatar = false,
  }) async {
    if (clearAvatar) {
      avatarBytes.value = null;
      avatarIcon.value = null;
      photoUrl.value = null;
    } else if (bytes != null) {
      avatarBytes.value = bytes;
      avatarIcon.value = null;
    } else if (icon != null) {
      avatarIcon.value = icon;
      avatarBytes.value = null;
      photoUrl.value = null;
    }
    if (newName != null) name.value = newName;
    if (newUsername != null) username.value = newUsername;
    if (newPhotoUrl != null) photoUrl.value = newPhotoUrl;

    await saveToStorage();
  }

  /// Uploads avatar bytes to remote storage and persists URL for the current user.
  Future<void> uploadAndPersistAvatar(Uint8List bytes) async {
    final userId = await _currentUserId();
    if (userId == null) {
      debugPrint('ProfileService: upload skipped — no authenticated UID');
      await updateProfile(bytes: bytes);
      return;
    }

    debugPrint('ProfileService: profile image upload started for UID=$userId');

    avatarBytes.value = bytes;
    avatarIcon.value = null;

    String? uploadedUrl;
    try {
      uploadedUrl = await FirebaseSettingsService.uploadProfilePhoto(
        userId: userId,
        bytes: bytes,
      );
    } catch (error) {
      debugPrint('ProfileService: profile image upload failed: $error');
    }

    if (uploadedUrl != null && uploadedUrl.trim().isNotEmpty) {
      photoUrl.value = uploadedUrl.trim();
      debugPrint('ProfileService: profile image upload success => $uploadedUrl');
      debugPrint('ProfileService: profile image URL saved => $uploadedUrl');
    } else {
      debugPrint('ProfileService: profile image stored locally (remote upload unavailable)');
    }

    await saveToStorage();
  }

  Future<void> hydrateFromAuthResult(Map<String, dynamic> source) async {
    final authUser = source['user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(source['user'] as Map)
        : source;

    final incomingName = (authUser['name'] ?? authUser['full_name'] ?? '').toString().trim();
    final incomingUsername = (authUser['username'] ?? '').toString().trim();
    final incomingPhotoUrl = (authUser['photoUrl'] ?? authUser['avatar_url'] ?? '').toString().trim();

    final key = await _storageKeyForCurrentUser();
    _activeUserKey = key;

    await loadFromStorage();

    if (incomingName.isNotEmpty) {
      name.value = incomingName;
    }
    if (incomingUsername.isNotEmpty) {
      username.value = incomingUsername.startsWith('@')
          ? incomingUsername
          : '@$incomingUsername';
    }

    if (incomingPhotoUrl.isNotEmpty) {
      photoUrl.value = incomingPhotoUrl;
      avatarBytes.value = null;
      avatarIcon.value = null;
      unawaited(_downloadPhotoBytes(incomingPhotoUrl));
    }

    await saveToStorage();
  }

  /// Removes persisted profile data for the current user (explicit reset only).
  Future<void> resetProfile() async {
    avatarBytes.value = null;
    avatarIcon.value = null;
    photoUrl.value = null;
    name.value = _defaultName;
    username.value = _defaultUsername;

    final prefs = await SharedPreferences.getInstance();
    final key = await _storageKeyForCurrentUser();
    debugPrint('ProfileService: resetting profile snapshot key=$key');
    await prefs.remove(key);
    await prefs.remove(_fallbackStoreKey);

    final userId = await _currentUserId();
    if (userId != null) {
      await FirebaseSettingsService.clearProfilePhoto(userId: userId);
    }
  }
}
