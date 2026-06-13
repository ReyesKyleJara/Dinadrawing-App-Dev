import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: '1:000000000000:web:00000000000000000000000',
      messagingSenderId: '000000000000',
      projectId: 'dinadrawing-demo',
      authDomain: 'dinadrawing-demo.firebaseapp.com',
      storageBucket: 'dinadrawing-demo.appspot.com',
      measurementId: 'G-0000000000',
    );
  }
}
