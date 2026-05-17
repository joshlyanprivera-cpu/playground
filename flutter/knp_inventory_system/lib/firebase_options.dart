import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA5CEbs5zLxB7zz5AVE_D_0syHb3NVnQAA',
    appId: '1:870135094746:web:a5c6674e3276db6038f4e3',
    messagingSenderId: '870135094746',
    projectId: 'knp-inventory',
    authDomain: 'knp-inventory.firebaseapp.com',
    storageBucket: 'knp-inventory.firebasestorage.app',
    measurementId: 'G-MBVLMQY790',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBpgZYfs5JLa-TlNrdqlLWHTBuHich46AI',
    appId: '1:870135094746:android:8de67c2d7702063f38f4e3',
    messagingSenderId: '870135094746',
    projectId: 'knp-inventory',
    storageBucket: 'knp-inventory.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAK6DmHUB7RIAWNE3LCfW9bnwn7UwRW4tQ',
    appId: '1:870135094746:ios:2c4c184926b342da38f4e3',
    messagingSenderId: '870135094746',
    projectId: 'knp-inventory',
    storageBucket: 'knp-inventory.firebasestorage.app',
    iosClientId: '870135094746-9q431fm59ahucsob7i0vdknolanbrd3d.apps.googleusercontent.com',
    iosBundleId: 'com.example.knpInventorySystem',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAK6DmHUB7RIAWNE3LCfW9bnwn7UwRW4tQ',
    appId: '1:870135094746:ios:2c4c184926b342da38f4e3',
    messagingSenderId: '870135094746',
    projectId: 'knp-inventory',
    storageBucket: 'knp-inventory.firebasestorage.app',
    iosClientId: '870135094746-9q431fm59ahucsob7i0vdknolanbrd3d.apps.googleusercontent.com',
    iosBundleId: 'com.example.knpInventorySystem',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA5CEbs5zLxB7zz5AVE_D_0syHb3NVnQAA',
    appId: '1:870135094746:web:a5c6674e3276db6038f4e3',
    messagingSenderId: '870135094746',
    projectId: 'knp-inventory',
    authDomain: 'knp-inventory.firebaseapp.com',
    storageBucket: 'knp-inventory.firebasestorage.app',
  );
}