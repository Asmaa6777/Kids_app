import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Push notifications (Firebase Cloud Messaging).
///
/// The Cloud Functions send *data* messages like
///   {type: 'call', familyId: …, contactId: …, callId: …}
///   {type: 'message', familyId: …, contactId: …, kind: 'sticker'}
/// and the app decides what to do (open the ringing screen, show a dot).
abstract interface class PushService {
  /// This device's push address: its Firebase Installation ID (null if unavailable or refused).
  Future<String?> token();

  /// Messages that arrive while the app is open, or that opened the app.
  Stream<Map<String, String>> get messages;
}

class FirebasePushService implements PushService {
  final _fm = FirebaseMessaging.instance;
  StreamController<Map<String, String>>? _out;

  @override
  Future<String?> token() async {
    try {
      final settings = await _fm.requestPermission(); // Android 13+ asks the user once
      if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
      // Current FCM API: register, then receive this install's ID (FID) once it's ready.
      final fid = _fm.onRegistered.first.timeout(const Duration(seconds: 20));
      await _fm.register();
      return await fid;
    } on Object {
      return null;
    }
  }

  @override
  Stream<Map<String, String>> get messages {
    _out ??= () {
      final c = StreamController<Map<String, String>>.broadcast();
      Map<String, String> data(RemoteMessage m) => m.data.map((k, v) => MapEntry(k, '$v'));
      FirebaseMessaging.onMessage.listen((m) => c.add(data(m)));
      FirebaseMessaging.onMessageOpenedApp.listen((m) => c.add(data(m)));
      _fm.getInitialMessage().then((m) {
        if (m != null) c.add(data(m));
      });
      return c;
    }();
    return _out!.stream;
  }
}

/// No push (offline mode, tests). [fake] lets tests "receive" a push.
class NoPushService implements PushService {
  final fake = StreamController<Map<String, String>>.broadcast();
  String? fakeToken;

  @override
  Future<String?> token() async => fakeToken;

  @override
  Stream<Map<String, String>> get messages => fake.stream;
}
