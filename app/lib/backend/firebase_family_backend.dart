import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../data/models.dart';
import '../theme/colors.dart';
import 'family_backend.dart';
import 'firebase_config.dart';

/// Calls one Cloud Function by name. An interface so tests can fake the server.
abstract interface class Callables {
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> data);
}

/// Uploads a local file (a voice note) and returns a URL to play it from.
abstract interface class FileUploader {
  Future<String> upload(String localPath, String remotePath, String contentType);
}

/// [FamilyBackend] on Firestore + Cloud Functions + Storage.
///
/// The Firestore layout and the security rules are in firebase/firestore.rules.
/// Field names here must match those rules exactly.
class FirebaseFamilyBackend implements FamilyBackend {
  FirebaseFamilyBackend({required this.db, required this.auth, required this.functions, required this.uploader});

  /// The real thing, for the app.
  factory FirebaseFamilyBackend.live() => FirebaseFamilyBackend(
    db: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    functions: _CloudCallables(FirebaseFunctions.instanceFor(region: FirebaseConfig.functionsRegion)),
    uploader: _StorageUploader(FirebaseStorage.instance),
  );

  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final Callables functions;
  final FileUploader uploader;

  String get _uid => auth.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> _family(String fid) => db.doc('families/$fid');

  @override
  Future<String> signIn() async => (auth.currentUser ?? (await auth.signInAnonymously()).user!).uid;

  // ---------------------------------------------------------------- mapping

  static Map<String, Object?> settingsToMap(AppSettings s) => {
    'typingAllowed': s.typingAllowed,
    'filtersAllowed': s.filtersAllowed,
    'quietOn': s.quietOn,
    'quietFrom': s.quietFromMinutes,
    'quietTo': s.quietToMinutes,
    // The server needs the child's time zone to check quiet hours itself.
    'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
  };

  static AppSettings settingsFromMap(Map<String, dynamic>? m) => AppSettings(
    typingAllowed: m?['typingAllowed'] as bool? ?? false,
    filtersAllowed: m?['filtersAllowed'] as bool? ?? true,
    quietOn: m?['quietOn'] as bool? ?? false,
    quietFromMinutes: m?['quietFrom'] as int? ?? 20 * 60,
    quietToMinutes: m?['quietTo'] as int? ?? 7 * 60,
  );

  static Map<String, Object?> messageToMap(ChatMessage m, {required bool iAmChild}) => {
    'from': iAmChild ? 'child' : 'contact',
    'type': m.type.name,
    'data': ?m.data,
    'dur': ?m.durationSeconds,
    // The server writes the time (the rules refuse anything else).
    'sentAt': FieldValue.serverTimestamp(),
  };

  static ChatMessage messageFromMap(Map<String, dynamic> d, {required bool iAmChild}) => ChatMessage(
    fromMe: (d['from'] == 'child') == iAmChild,
    type: MessageType.values.asNameMap()[d['type']] ?? MessageType.text,
    data: d['data'] as String?,
    durationSeconds: d['dur'] as int?,
    // Just-sent messages have no server time yet: show them as "now".
    sentAt: (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  // ---------------------------------------------------------------- parent

  @override
  Future<String> createFamily({
    required String childName,
    required AppSettings settings,
    required List<Contact> contacts,
  }) async {
    final uid = await signIn();
    final ref = db.collection('families').doc();
    // Family + owner membership in ONE batch: the rules require both together.
    final batch = db.batch()
      ..set(ref, {
        'childName': childName,
        'ownerUid': uid,
        'settings': settingsToMap(settings),
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(ref.collection('members').doc(uid), {'role': 'owner'});
    await batch.commit();
    await saveContacts(ref.id, contacts);
    await db.doc('users/$uid').set({'familyId': ref.id}, SetOptions(merge: true));
    return ref.id;
  }

  @override
  Future<void> saveContacts(String familyId, List<Contact> contacts) async {
    final batch = db.batch();
    for (final (i, c) in contacts.indexed) {
      batch.set(_family(familyId).collection('contacts').doc(c.id), {
        'name': c.name,
        'color': c.color.name,
        'order': i,
      }, SetOptions(merge: true)); // merge keeps 'uid' of relatives who already joined
    }
    await batch.commit();
  }

  @override
  Future<void> deleteContact(String familyId, String contactId) =>
      _family(familyId).collection('contacts').doc(contactId).delete();

  @override
  Future<void> saveSettings(String familyId, AppSettings settings) =>
      _family(familyId).update({'settings': settingsToMap(settings)});

  @override
  Future<Invite> createInvite(String familyId, String contactId) async {
    final r = await functions.call('createInvite', {'familyId': familyId, 'contactId': contactId});
    final expires = DateTime.fromMillisecondsSinceEpoch(r['expiresAt'] as int);
    return Invite(code: r['code'] as String, createdAt: expires.subtract(const Duration(hours: 48)));
  }

  @override
  Future<void> deleteFamily(String familyId) => functions.call('deleteFamily', {'familyId': familyId});

  // ---------------------------------------------------------------- relative

  @override
  Future<JoinResult> redeemInvite(String code, String name) async {
    await signIn();
    final r = await functions.call('redeemInvite', {'code': code, 'name': name});
    return JoinResult(
      familyId: r['familyId'] as String,
      contactId: r['contactId'] as String,
      childName: r['childName'] as String,
      contactName: r['contactName'] as String,
      color: r['color'] as String,
    );
  }

  // ---------------------------------------------------------------- both

  @override
  Stream<RemoteFamily> watchFamily(String familyId) {
    final family = _family(familyId);
    // Combine two live queries: the family doc and its contacts.
    // Every time either changes, emit a fresh RemoteFamily.
    DocumentSnapshot<Map<String, dynamic>>? fam;
    QuerySnapshot<Map<String, dynamic>>? contacts;
    RemoteFamily? build() {
      if (fam?.data() == null || contacts == null) return null;
      final docs = [...contacts!.docs]..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
      return RemoteFamily(
        childName: fam!['childName'] as String,
        settings: settingsFromMap(fam!['settings'] as Map<String, dynamic>?),
        contacts: [
          for (final d in docs)
            Contact(id: d.id, name: d['name'] as String, color: FamilyColor.byName(d['color'] as String)),
        ],
        joined: {
          for (final d in docs)
            if (d.data()['uid'] != null) d.id,
        },
      );
    }

    return Stream.multi((sink) {
      final a = family.snapshots().listen((s) {
        fam = s;
        final r = build();
        if (r != null) sink.add(r);
      }, onError: sink.addError);
      final b = family.collection('contacts').snapshots().listen((s) {
        contacts = s;
        final r = build();
        if (r != null) sink.add(r);
      }, onError: sink.addError);
      sink.onCancel = () {
        a.cancel();
        b.cancel();
      };
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String familyId, String contactId, {required bool iAmChild}) =>
      _family(familyId)
          .collection('threads/$contactId/messages')
          .orderBy('sentAt')
          .limitToLast(200)
          .snapshots()
          .map((s) => [for (final d in s.docs) messageFromMap(d.data(), iAmChild: iAmChild)]);

  @override
  Future<void> sendMessage(String familyId, String contactId, ChatMessage message, {required bool iAmChild}) async {
    var m = message;
    // Voice notes: upload the recording first, then send its URL in the message.
    if (m.type == MessageType.voice && m.data != null && !m.data!.startsWith('http')) {
      final name = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final url = await uploader.upload(m.data!, 'families/$familyId/threads/$contactId/$name', 'audio/mp4');
      m = ChatMessage(fromMe: true, type: m.type, data: url, durationSeconds: m.durationSeconds, sentAt: m.sentAt);
    }
    await _family(familyId).collection('threads/$contactId/messages').add(messageToMap(m, iAmChild: iAmChild));
  }

  @override
  Future<void> ring(String familyId, String contactId, {required bool iAmChild}) => _family(familyId)
      .collection('calls')
      .add({
        'contactId': contactId,
        'from': iAmChild ? 'child' : 'contact',
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<CallToken> callToken(String familyId, String contactId) async {
    final r = await functions.call('livekitToken', {'familyId': familyId, 'contactId': contactId});
    return CallToken(url: r['url'] as String, token: r['token'] as String, room: r['room'] as String);
  }

  @override
  Future<void> registerPushToken(String token) => db.doc('users/$_uid').set({
    'fids': FieldValue.arrayUnion([token]),
  }, SetOptions(merge: true));
}

class _CloudCallables implements Callables {
  _CloudCallables(this._fns);
  final FirebaseFunctions _fns;

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> data) async {
    try {
      final r = await _fns.httpsCallable(name).call<Map<String, dynamic>>(data);
      return Map<String, dynamic>.from(r.data);
    } on FirebaseFunctionsException catch (e) {
      // The functions send friendly messages ("Sleepy time — …"); pass them on.
      throw BackendException(e.message ?? 'Something went wrong', code: e.code);
    }
  }
}

class _StorageUploader implements FileUploader {
  _StorageUploader(this._storage);
  final FirebaseStorage _storage;

  @override
  Future<String> upload(String localPath, String remotePath, String contentType) async {
    final ref = _storage.ref(remotePath);
    await ref.putFile(File(localPath), SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
