import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final googleAuthentication = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuthentication.accessToken,
        idToken: googleAuthentication.idToken,
      );

      return await _firebaseAuth.signInWithCredential(credential);
    } catch (error, stackTrace) {
      debugPrint('GOOGLE SIGN-IN ERROR: $error');

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  Future<String?> getFirebaseIdToken({bool forceRefresh = false}) async {
    return _firebaseAuth.currentUser?.getIdToken(forceRefresh);
  }

  Future<void> signOut() async {
    await Future.wait([_googleSignIn.signOut(), _firebaseAuth.signOut()]);
  }
}
