import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// How the app finds its Firebase project. Chosen at build time, no file to generate:
///
///   Real project:   flutter run --dart-define-from-file=firebase.env.json
///                   (copy firebase.env.example.json and fill in the values from the Firebase console)
///   Local emulators: flutter run --dart-define=FIREBASE_EMULATOR=10.0.2.2
///                   (10.0.2.2 is "my computer" as seen from the Android emulator)
///   Neither:        the app runs offline on this device only, as before.
abstract final class FirebaseConfig {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _bucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const emulatorHost = String.fromEnvironment('FIREBASE_EMULATOR');

  /// The Cloud Functions region (must match `REGION` in firebase/functions/src/index.ts).
  static const functionsRegion = 'europe-west1';

  static bool get usesEmulator => emulatorHost.isNotEmpty;
  static bool get enabled => usesEmulator || (_apiKey.isNotEmpty && _appId.isNotEmpty && _projectId.isNotEmpty);

  static FirebaseOptions get options => usesEmulator
      ? const FirebaseOptions(
          apiKey: 'demo-key',
          appId: '1:1:android:1',
          messagingSenderId: '1',
          projectId: 'demo-familycall', // "demo-" projects only exist in the emulator
          storageBucket: 'demo-familycall.appspot.com',
        )
      : const FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
          storageBucket: _bucket,
        );

  static Future<void> initialize() async {
    await Firebase.initializeApp(options: options);
    if (usesEmulator) {
      await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
      await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
      FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(emulatorHost, 5001);
    }
  }
}
