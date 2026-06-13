import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dinadrawing/services/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ProfileService generates UID-based storage keys and isolates snapshots', () async {
    final keyA = ProfileService.storageKeyForUser(
      userId: 'user-a',
      email: 'user-a@example.com',
    );
    final keyB = ProfileService.storageKeyForUser(
      userId: 'user-b',
      email: 'user-b@example.com',
    );

    expect(keyA, isNot(equals(keyB)));
    expect(keyA, contains('user-a'));
    expect(keyB, contains('user-b'));

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      keyA,
      const JsonEncoder().convert({
        'name': 'User A',
        'username': '@usera',
        'photoUrl': 'https://example.com/user-a.jpg',
        'avatarBytes': base64Encode(Uint8List.fromList([1, 2, 3])),
      }),
    );

    expect(prefs.getString(keyA), isNotNull);
    expect(prefs.getString(keyB), isNull);
  });

  test('ProfileService persists avatar data locally with photoUrl', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const userId = 'user-persist';
    final key = ProfileService.storageKeyForUser(userId: userId, email: null);

    await prefs.setString(
      key,
      const JsonEncoder().convert({
        'name': 'Persist User',
        'username': '@persist',
        'photoUrl': 'https://example.com/persist.jpg',
        'avatarBytes': base64Encode(Uint8List.fromList([9, 8, 7])),
      }),
    );

    final raw = prefs.getString(key);
    expect(raw, isNotNull);

    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    expect(decoded['photoUrl'], 'https://example.com/persist.jpg');
    expect(decoded['avatarBytes'], isNotEmpty);
  });

  test('clearInMemoryCache does not delete UID-scoped SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const userId = 'user-cache';
    final key = ProfileService.storageKeyForUser(userId: userId, email: null);

    await prefs.setString(
      key,
      const JsonEncoder().convert({
        'name': 'Cached User',
        'username': '@cached',
        'photoUrl': 'https://example.com/cached.jpg',
        'avatarBytes': base64Encode(Uint8List.fromList([4, 5, 6])),
      }),
    );

    await ProfileService.instance.clearInMemoryCache();

    expect(ProfileService.instance.avatarBytes.value, isNull);
    expect(ProfileService.instance.photoUrl.value, isNull);
    expect(prefs.getString(key), isNotNull);
  });

  test('User B storage key cannot read User A avatar snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final keyA = ProfileService.storageKeyForUser(userId: '111', email: 'a@test.com');
    final keyB = ProfileService.storageKeyForUser(userId: '222', email: 'b@test.com');

    await prefs.setString(
      keyA,
      const JsonEncoder().convert({
        'name': 'User A',
        'username': '@usera',
        'photoUrl': 'https://example.com/a.jpg',
        'avatarBytes': base64Encode(Uint8List.fromList([10, 11, 12])),
      }),
    );

    final userBRaw = prefs.getString(keyB);
    expect(userBRaw, isNull);

    final userARaw = prefs.getString(keyA);
    expect(userARaw, isNotNull);
    final decoded = jsonDecode(userARaw!) as Map<String, dynamic>;
    expect(decoded['photoUrl'], 'https://example.com/a.jpg');
  });
}
