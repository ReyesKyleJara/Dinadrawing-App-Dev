import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dinadrawing/firebase_options.dart';
import 'package:dinadrawing/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseSettingsService {
  static Future<bool> ensureFirebaseReady() async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('FirebaseSettingsService: initializing Firebase app');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      debugPrint('FirebaseSettingsService: Firebase ready (apps=${Firebase.apps.length})');
      return true;
    } catch (error, stackTrace) {
      debugPrint('FirebaseSettingsService: Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static User? get currentUser {
    try {
      if (Firebase.apps.isEmpty) {
        return null;
      }
      return FirebaseAuth.instance.currentUser;
    } catch (error) {
      debugPrint('FirebaseSettingsService: currentUser unavailable: $error');
      return null;
    }
  }

  static Future<Map<String, dynamic>> loadProfile() async {
    final user = currentUser;
    if (user == null) {
      return {'user': null};
    }

    return loadProfileForUser(user.uid);
  }

  /// Loads profile from Firestore using an explicit backend/Firebase user id.
  static Future<Map<String, dynamic>> loadProfileForUser(String userId) async {
    if (Firebase.apps.isEmpty) {
      return {'success': false, 'message': 'Firebase is not available on this platform.'};
    }

    final snapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = snapshot.data() ?? <String, dynamic>{};

    final firebaseUser = currentUser;

    return {
      'user': firebaseUser,
      'profile': {
        'name': data['displayName'] ?? firebaseUser?.displayName ?? 'User',
        'email': data['email'] ?? firebaseUser?.email ?? '',
        'photoUrl': data['photoUrl'] ?? firebaseUser?.photoURL,
        'username': data['username'] ??
            firebaseUser?.email?.split('@').first ??
            '',
      },
    };
  }

  /// Uploads profile photo to Firebase Storage and saves URL in Firestore for [userId].
  static Future<String?> uploadProfilePhoto({
    required String userId,
    required Uint8List bytes,
  }) async {
    final firebaseReady = await ensureFirebaseReady();
    if (!firebaseReady || Firebase.apps.isEmpty) {
      debugPrint('FirebaseSettingsService: upload skipped — Firebase unavailable');
      return null;
    }

    try {
      final storageRef =
          FirebaseStorage.instance.ref().child('profile_images/$userId.jpg');
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await storageRef.getDownloadURL();

      debugPrint('FirebaseSettingsService: profile image URL saved for UID=$userId => $downloadUrl');

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'photoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await firebaseUser.updatePhotoURL(downloadUrl);
      }

      return downloadUrl;
    } catch (e) {
      debugPrint('FirebaseSettingsService: uploadProfilePhoto failed: $e');
      return null;
    }
  }

  static Future<void> clearProfilePhoto({required String userId}) async {
    if (Firebase.apps.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'photoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirebaseSettingsService: clearProfilePhoto failed: $e');
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? photoUrl,
  }) async {
    debugPrint('FirebaseSettingsService: updateProfile requested for $name');

    final firebaseReady = await ensureFirebaseReady();
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    if (user == null) {
      return {'success': false, 'message': 'No authenticated user found.'};
    }

    try {
      await user.updateDisplayName(name.trim());
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        await user.updatePhotoURL(photoUrl.trim());
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': name.trim(),
        'email': user.email,
        'photoUrl': photoUrl ?? user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.reload();

      return {
        'success': true,
        'message': 'Profile updated successfully.',
        'user': FirebaseAuth.instance.currentUser,
      };
    } catch (e) {
      debugPrint('FirebaseSettingsService: updateProfile failed: $e');
      return {'success': false, 'message': 'Profile update failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    debugPrint('FirebaseSettingsService: changePassword requested');

    if (newPassword != confirmPassword) {
      return {'success': false, 'message': 'New password and confirmation do not match.'};
    }

    final firebaseReady = await ensureFirebaseReady();
    final user = firebaseReady ? FirebaseAuth.instance.currentUser : null;

    if (user != null && user.email != null) {
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );

        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPassword);

        return {'success': true, 'message': 'Password updated successfully.'};
      } on FirebaseAuthException catch (e) {
        debugPrint('FirebaseSettingsService: Firebase password change failed: ${e.code} ${e.message}');
        return {
          'success': false,
          'message': e.code == 'wrong-password'
              ? 'Current password is incorrect.'
              : (e.message ?? 'Unable to change password.'),
        };
      } catch (e) {
        debugPrint('FirebaseSettingsService: Firebase password change failed: $e');
        return {'success': false, 'message': 'Unable to change password: $e'};
      }
    }

    debugPrint('FirebaseSettingsService: falling back to backend password change');
    return AuthService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }
}
