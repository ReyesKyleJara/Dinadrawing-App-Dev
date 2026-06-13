import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('========== GOOGLE SIGN IN STARTED ==========');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('User cancelled Google Sign-In');
        return null;
      }

      debugPrint('Google User Selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint('Access Token: ${googleAuth.accessToken != null}');
      debugPrint('ID Token: ${googleAuth.idToken != null}');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      debugPrint('========== FIREBASE LOGIN SUCCESS ==========');
      debugPrint('UID: ${userCredential.user?.uid}');
      debugPrint('NAME: ${userCredential.user?.displayName}');
      debugPrint('EMAIL: ${userCredential.user?.email}');
      debugPrint('===========================================');

      return userCredential;
    } catch (e, stackTrace) {
      debugPrint('===========================================');
      debugPrint('GOOGLE SIGN IN ERROR');
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());
      debugPrint('===========================================');

      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
