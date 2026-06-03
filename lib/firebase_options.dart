import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
    apiKey: 'AIzaSyArE56yeA2Fqf1H7_r5Kx3QyymCdaZgc2Y',
    appId: '1:578920433940:web:bc5df72d0a3699925c9a01',
    messagingSenderId: '578920433940',
    projectId: 'joke-book-d1510',
    authDomain: 'joke-book-d1510.firebaseapp.com',
    storageBucket: 'joke-book-d1510.firebasestorage.app',
    measurementId: 'G-L4CHTJ44TQ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDmTCVsMbCf7sTNE2hu13u2A-83AExLIC8',
    appId: '1:578920433940:android:29ef849e51996b9b5c9a01',
    messagingSenderId: '578920433940',
    projectId: 'joke-book-d1510',
    storageBucket: 'joke-book-d1510.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDk6DMLNwdDxhZ8HNRuQOfRf9aCJ697QLk',
    appId: '1:578920433940:ios:ff922983108e9bcd5c9a01',
    messagingSenderId: '578920433940',
    projectId: 'joke-book-d1510',
    storageBucket: 'joke-book-d1510.firebasestorage.app',
    androidClientId: '578920433940-1ahmbrdsadfmbmuhh7h26g6je2985vjv.apps.googleusercontent.com',
    iosClientId: '578920433940-118ki5kdfh6lbav0fc65p5dpekcte8ju.apps.googleusercontent.com',
    iosBundleId: 'com.jokebook.jokebook',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDk6DMLNwdDxhZ8HNRuQOfRf9aCJ697QLk',
    appId: '1:578920433940:ios:f10e3f6dd59716505c9a01',
    messagingSenderId: '578920433940',
    projectId: 'joke-book-d1510',
    storageBucket: 'joke-book-d1510.firebasestorage.app',
    androidClientId: '578920433940-1ahmbrdsadfmbmuhh7h26g6je2985vjv.apps.googleusercontent.com',
    iosClientId: '578920433940-kho40q93mibq479jir05vk8ee9lqigsu.apps.googleusercontent.com',
    iosBundleId: 'com.kennedyai.jokebook',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyArE56yeA2Fqf1H7_r5Kx3QyymCdaZgc2Y',
    appId: '1:578920433940:web:bd17eeab20f1fa865c9a01',
    messagingSenderId: '578920433940',
    projectId: 'joke-book-d1510',
    authDomain: 'joke-book-d1510.firebaseapp.com',
    storageBucket: 'joke-book-d1510.firebasestorage.app',
    measurementId: 'G-YQ3EYWWTR2',
  );

}