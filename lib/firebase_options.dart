// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
    apiKey: 'AIzaSyAbBpkSCLwy2p4dimBjXNh5XXIiQSz9FnI',
    appId: '1:657690570978:web:d5fe3753d529e147646ebb',
    messagingSenderId: '657690570978',
    projectId: 'kasie-transie-4',
    authDomain: 'kasie-transie-4.firebaseapp.com',
    storageBucket: 'kasie-transie-4.firebasestorage.app',
    measurementId: 'G-HW0HV14FX5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD5AGxqLVyDNjRoRRDYVcnBq6_HMPAu3MU',
    appId: '1:657690570978:android:ed074c6d3686f73e646ebb',
    messagingSenderId: '657690570978',
    projectId: 'kasie-transie-4',
    storageBucket: 'kasie-transie-4.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDp6_YeoB_osu_79GswDFtmegbU_8R4ISs',
    appId: '1:657690570978:ios:5699d73ad47039b1646ebb',
    messagingSenderId: '657690570978',
    projectId: 'kasie-transie-4',
    storageBucket: 'kasie-transie-4.firebasestorage.app',
    iosBundleId: 'com.kasie.associationOfficialApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDp6_YeoB_osu_79GswDFtmegbU_8R4ISs',
    appId: '1:657690570978:ios:5699d73ad47039b1646ebb',
    messagingSenderId: '657690570978',
    projectId: 'kasie-transie-4',
    storageBucket: 'kasie-transie-4.firebasestorage.app',
    iosBundleId: 'com.kasie.associationOfficialApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAbBpkSCLwy2p4dimBjXNh5XXIiQSz9FnI',
    appId: '1:657690570978:web:91759caede232e55646ebb',
    messagingSenderId: '657690570978',
    projectId: 'kasie-transie-4',
    authDomain: 'kasie-transie-4.firebaseapp.com',
    storageBucket: 'kasie-transie-4.firebasestorage.app',
    measurementId: 'G-MFXB1FYY62',
  );
}
