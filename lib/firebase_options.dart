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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyArE56yeA2Fqf1H7_r5Kx3QyymCdaZgc2Y',
    appId: '1:578920433940:web:6d604cb4e8d354705c9a01',
    messagingSenderId: '578920433940',
    projectId: 'joke-book-d1510',
    authDomain: 'joke-book-d1510.firebaseapp.com',
    storageBucket: 'joke-book-d1510.firebasestorage.app',
    measurementId: 'G-KGZ6NHSM73',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDmTCVsMbCf7sTNE2hu13u2A-83AExLIC8',
    appId: '1:578920433940:android:b362740710668f2b5c9a01',
    messagingSenderId: '578920433940',
    projectId: 'joke-book-d1510',
    storageBucket: 'joke-book-d1510.firebasestorage.app',
  );
}