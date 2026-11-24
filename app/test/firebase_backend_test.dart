import 'package:family_call/backend/family_backend.dart';
import 'package:family_call/backend/firebase_family_backend.dart';
import 'package:family_call/data/models.dart';
import 'package:family_call/theme/colors.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the Cloud Functions: records calls, returns canned answers.
class FakeCallables implements Callables {
  final calls = <(String, Map<String, Object?>)>[];
  Map<String, dynamic> Function(String name, Map<String, Object?> data) answer = (_, _) => {};

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> data) async {
    calls.add((name, data));
    return answer(name, data);
  }
}

class FakeUploader implements FileUploader {
  final uploads = <(String, String)>[];
  @override
  Future<String> upload(String localPath, String remotePath, String contentType) async {
    uploads.add((localPath, remotePath));
    return 'https://storage.example/$remotePath';
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late FakeCallables fns;
  late FakeUploader uploader;
  late FirebaseFamilyBackend backend;

  const contacts = [
    Contact(id: 'g', name: 'Grandma', color: FamilyColor.coral),
    Contact(id: 'u', name: 'Uncle Omar', color: FamilyColor.blue),
  ];

  setUp(() {
    db = FakeFirebaseFirestore();
    fns = FakeCallables();
    uploader = FakeUploader();
    backend = FirebaseFamilyBackend(
      db: db,
      auth: MockFirebaseAuth(mockUser: MockUser(uid: 'parent-uid', isAnonymous: true)),
      functions: fns,
      uploader: uploader,
    );
  });

  test('createFamily writes the family, the owner membership and ordered contacts', () async {
    final fid = await backend.createFamily(
      childName: 'Mia',
      settings: const AppSettings(quietOn: true),
      contacts: contacts,
    );

    final fam = (await db.doc('families/$fid').get()).data()!;
    expect(fam['childName'], 'Mia');
    expect(fam['ownerUid'], 'parent-uid');
    expect((fam['settings'] as Map)['quietOn'], isTrue);
    expect((fam['settings'] as Map)['utcOffsetMinutes'], isA<int>());
    expect((await db.doc('families/$fid/members/parent-uid').get()).data(), {'role': 'owner'});
    expect((await db.doc('families/$fid/contacts/u').get()).data(), {
      'name': 'Uncle Omar',
      'color': 'blue',
      'order': 1,
    });
    expect((await db.doc('users/parent-uid').get()).data(), {'familyId': fid});
  });

  test('watchFamily combines the family and its contacts, in order, and marks who joined', () async {
    final fid = await backend.createFamily(childName: 'Mia', settings: const AppSettings(), contacts: contacts);
    await db.doc('families/$fid/contacts/g').update({'uid': 'grandma-uid'}); // as redeemInvite would

    final first = await backend.watchFamily(fid).first;
    expect(first.childName, 'Mia');
    expect(first.contacts.map((c) => c.id), ['g', 'u']);
    expect(first.joined, {'g'});

    // Reordering (parent moves Uncle Omar first) shows up in the stream.
    await backend.saveContacts(fid, contacts.reversed.toList());
    final reordered = await backend.watchFamily(fid).first;
    expect(reordered.contacts.map((c) => c.id), ['u', 'g']);
    expect(reordered.joined, {'g'}, reason: 'merge must keep the uid of a joined relative');
  });

  test('settings round-trip through Firestore field names', () async {
    final fid = await backend.createFamily(childName: 'Mia', settings: const AppSettings(), contacts: contacts);
    const s = AppSettings(
      typingAllowed: true,
      filtersAllowed: false,
      quietOn: true,
      quietFromMinutes: 1260,
      quietToMinutes: 390,
    );
    await backend.saveSettings(fid, s);
    final back = (await backend.watchFamily(fid).first).settings;
    expect(
      [back.typingAllowed, back.filtersAllowed, back.quietOn, back.quietFromMinutes, back.quietToMinutes],
      [true, false, true, 1260, 390],
    );
  });

  test('messages: "from" decides fromMe for each side; voice notes are uploaded first', () async {
    final fid = await backend.createFamily(childName: 'Mia', settings: const AppSettings(), contacts: contacts);
    await backend.sendMessage(
      fid,
      'g',
      ChatMessage(fromMe: true, type: MessageType.sticker, data: 'star', sentAt: DateTime.now()),
      iAmChild: true,
    );
    await backend.sendMessage(
      fid,
      'g',
      ChatMessage(
        fromMe: true,
        type: MessageType.voice,
        data: '/local/v.m4a',
        durationSeconds: 3,
        sentAt: DateTime.now(),
      ),
      iAmChild: false,
    );

    expect(uploader.uploads.single.$1, '/local/v.m4a');
    expect(uploader.uploads.single.$2, startsWith('families/$fid/threads/g/'));

    final childView = await backend.watchMessages(fid, 'g', iAmChild: true).first;
    expect(childView.map((m) => m.fromMe), [true, false]);
    final grandmaView = await backend.watchMessages(fid, 'g', iAmChild: false).first;
    expect(grandmaView.map((m) => m.fromMe), [false, true]);
    expect(grandmaView.last.data, startsWith('https://storage.example/'));
    expect(grandmaView.last.durationSeconds, 3);
  });

  test('ring writes a call document the trigger will push', () async {
    final fid = await backend.createFamily(childName: 'Mia', settings: const AppSettings(), contacts: contacts);
    await backend.ring(fid, 'u', iAmChild: true);
    final call = (await db.collection('families/$fid/calls').get()).docs.single.data();
    expect([call['contactId'], call['from'], call['status']], ['u', 'child', 'ringing']);
  });

  test('invites, joining and call tokens go through Cloud Functions', () async {
    fns.answer = (name, data) => switch (name) {
      'createInvite' => {'code': 'K7MZQ2', 'expiresAt': DateTime(2026, 1, 3).millisecondsSinceEpoch},
      'redeemInvite' => {
        'familyId': 'f1',
        'contactId': 'g',
        'childName': 'Mia',
        'contactName': 'Grandma',
        'color': 'coral',
      },
      'livekitToken' => {'url': 'wss://x', 'token': 'jwt', 'room': 'f1_g'},
      _ => {},
    };

    final invite = await backend.createInvite('f1', 'g');
    expect(invite.code, 'K7MZQ2');
    expect(invite.createdAt, DateTime(2026, 1, 1)); // 48 h before expiry

    final join = await backend.redeemInvite('k7mzq2', 'Nana');
    expect([join.familyId, join.contactId, join.childName], ['f1', 'g', 'Mia']);

    final token = await backend.callToken('f1', 'g');
    expect(token.room, 'f1_g');

    expect(fns.calls.map((c) => c.$1), ['createInvite', 'redeemInvite', 'livekitToken']);
    expect(fns.calls[1].$2, {'code': 'k7mzq2', 'name': 'Nana'});
  });

  test('push tokens are added without duplicates', () async {
    await backend.signIn();
    await backend.registerPushToken('t1');
    await backend.registerPushToken('t1');
    await backend.registerPushToken('t2');
    expect((await db.doc('users/parent-uid').get()).data()!['fcmTokens'], ['t1', 't2']);
  });

  test('BackendException shows the server message', () {
    expect(const BackendException('Sleepy time', code: 'failed-precondition').toString(), 'Sleepy time');
  });
}
