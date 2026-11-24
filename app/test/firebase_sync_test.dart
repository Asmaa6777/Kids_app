import 'package:family_call/app/app.dart';
import 'package:family_call/backend/firebase_family_backend.dart';
import 'package:family_call/data/family_repository.dart';
import 'package:family_call/data/family_store.dart';
import 'package:family_call/data/models.dart';
import 'package:family_call/services/app_services.dart';
import 'package:family_call/services/push.dart';
import 'package:family_call/theme/colors.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'firebase_backend_test.dart' show FakeUploader;

/// A tiny stand-in for the Cloud Functions, doing the same writes the real ones do.
class FakeServer implements Callables {
  FakeServer(this.db, this.uid);
  final FakeFirebaseFirestore db;
  final String uid; // who is "calling" the function
  static final invites = <String, (String fid, String cid)>{};
  static final deleted = <String>[];

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> data) async {
    switch (name) {
      case 'createInvite':
        final code = 'CODE${invites.length + 2}'.replaceAll('0', 'Q');
        invites[code] = (data['familyId']! as String, data['contactId']! as String);
        return {'code': code, 'expiresAt': DateTime.now().add(const Duration(hours: 48)).millisecondsSinceEpoch};
      case 'redeemInvite':
        final (fid, cid) = invites.remove((data['code']! as String).toUpperCase())!;
        await db.doc('families/$fid/members/$uid').set({'role': 'relative', 'contactId': cid});
        await db.doc('families/$fid/contacts/$cid').update({'uid': uid});
        final fam = (await db.doc('families/$fid').get()).data()!;
        final contact = (await db.doc('families/$fid/contacts/$cid').get()).data()!;
        return {
          'familyId': fid,
          'contactId': cid,
          'childName': fam['childName'],
          'contactName': contact['name'],
          'color': contact['color'],
        };
      case 'deleteFamily':
        deleted.add(data['familyId']! as String);
        return {'deleted': true};
    }
    return {};
  }
}

/// Lets Firestore's (fake) live streams deliver their updates.
/// (A short real delay: chained batch writes take more than a few microtasks to arrive.)
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late FakeFirebaseFirestore db;

  FamilyStore phone(String uid) {
    final backend = FirebaseFamilyBackend(
      db: db,
      auth: MockFirebaseAuth(mockUser: MockUser(uid: uid, isAnonymous: true)),
      functions: FakeServer(db, uid),
      uploader: FakeUploader(),
    );
    final repo = InMemoryFamilyRepository(FamilyState.demo());
    return FamilyStore(repo, repo.state, backend: backend);
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    FakeServer.invites.clear();
    FakeServer.deleted.clear();
  });

  /// The full story: parent sets up the tablet, invites Grandma, they chat.
  Future<(FamilyStore, FamilyStore)> parentAndGrandma() async {
    final child = phone('parent-uid');
    await child.completeParentSetup(childName: 'Mia', pin: '1234');
    await settle();
    final code = (await child.createInvite('g')).code;
    final grandma = phone('grandma-uid');
    expect(await grandma.joinFamily(code: code, name: 'Nana', color: FamilyColor.purple), isNull);
    await settle();
    return (child, grandma);
  }

  test('parent setup online creates the family on the server', () async {
    final child = phone('parent-uid');
    await child.completeParentSetup(childName: 'Mia', pin: '1234');
    expect(child.online, isTrue);
    final fid = child.state.familyId!;
    expect((await db.doc('families/$fid').get()).data()!['ownerUid'], 'parent-uid');
    expect((await db.collection('families/$fid/contacts').get()).docs, hasLength(6));
  });

  test('a relative joins with a code and becomes that contact', () async {
    final (child, grandma) = await parentAndGrandma();
    expect(grandma.online, isTrue);
    expect(grandma.state.role, Role.family);
    expect(grandma.state.familyId, child.state.familyId);
    expect(grandma.state.myContactId, 'g');
    expect(grandma.state.me!.name, 'Grandma', reason: 'the parent chose the tile name');
    expect(grandma.state.childName, 'Mia');
    expect(child.state.joined, {'g'}, reason: 'the parent sees that Grandma joined');
  });

  test('messages flow both ways, with unread dots only when the chat is closed', () async {
    final (child, grandma) = await parentAndGrandma();

    grandma.sendMessage(
      'child',
      ChatMessage(fromMe: true, type: MessageType.sticker, data: 'heart', sentAt: DateTime.now()),
    );
    await settle();
    expect(child.messagesWith('g').single.data, 'heart');
    expect(child.messagesWith('g').single.fromMe, isFalse);
    expect(child.state.unread, contains('g'));

    child.openChat('g');
    expect(child.state.unread, isNot(contains('g')));
    child.sendMessage('g', ChatMessage(fromMe: true, type: MessageType.sticker, data: 'star', sentAt: DateTime.now()));
    await settle();
    expect(child.state.unread, isNot(contains('g')), reason: 'own messages never count as unread');
    expect(grandma.messagesWith('child').map((m) => (m.data, m.fromMe)), [('heart', true), ('star', false)]);
    expect(grandma.state.unread, contains('child'));
  });

  test('a slow voice-note upload does not let a later sticker overtake it', () async {
    final (child, _) = await parentAndGrandma();
    final slow = FirebaseFamilyBackend(
      db: db,
      auth: MockFirebaseAuth(mockUser: MockUser(uid: 'parent-uid', isAnonymous: true)),
      functions: FakeServer(db, 'parent-uid'),
      uploader: _SlowUploader(),
    );
    final repo = InMemoryFamilyRepository(child.state);
    final tablet = FamilyStore(repo, repo.state, backend: slow);

    tablet.sendMessage(
      'g',
      ChatMessage(fromMe: true, type: MessageType.voice, data: '/v.m4a', durationSeconds: 2, sentAt: DateTime.now()),
    );
    tablet.sendMessage('g', ChatMessage(fromMe: true, type: MessageType.sticker, data: 'star', sentAt: DateTime.now()));
    await tablet.pendingWrites;
    await settle();
    expect(tablet.messagesWith('g').map((m) => m.type), [MessageType.voice, MessageType.sticker]);
    tablet.dispose();
  });

  test('Uncle Omar\'s thread stays separate from Grandma\'s', () async {
    final (child, grandma) = await parentAndGrandma();
    child.sendMessage('u', ChatMessage(fromMe: true, type: MessageType.sticker, data: 'sun', sentAt: DateTime.now()));
    await settle();
    expect(grandma.messagesWith('child'), isEmpty);
    expect(child.messagesWith('u').single.data, 'sun');
  });

  test('parent changes (settings, new contact, order) reach the relative\'s phone', () async {
    final (child, grandma) = await parentAndGrandma();
    child.updateSettings(child.state.settings.copyWith(quietOn: true, typingAllowed: true));
    child.addContact('Cousin Sara', FamilyColor.green);
    child.moveContact('g', 1);
    await settle();
    expect(grandma.state.settings.quietOn, isTrue);
    expect(grandma.state.settings.typingAllowed, isTrue);
    expect(grandma.state.contacts.last.name, 'Cousin Sara');
    expect(grandma.state.contacts[1].id, 'g');
    expect(grandma.state.joined, {'g'}, reason: 'reordering must not unlink Grandma');
  });

  test('calls: ringing writes a call doc, and both sides target the same thread', () async {
    final (child, grandma) = await parentAndGrandma();
    grandma.ring('child');
    await settle();
    final call = (await db.collection('families/${child.state.familyId}/calls').get()).docs.single.data();
    expect([call['contactId'], call['from']], ['g', 'contact']);
    expect(grandma.callTarget('child')!.threadId, 'g');
    expect(child.callTarget('g')!.threadId, 'g');
  });

  test('a bad code shows the server\'s message instead of crashing', () async {
    final grandma = phone('grandma-uid');
    final error = await grandma.joinFamily(code: 'NOPE22', name: 'Nana', color: FamilyColor.coral);
    expect(error, isNotNull);
    expect(grandma.state.isSetUp, isFalse);
  });

  test('delete all data asks the server, then resets this device', () async {
    final (child, _) = await parentAndGrandma();
    final fid = child.state.familyId!;
    await child.deleteAllData();
    expect(FakeServer.deleted, [fid]);
    expect(child.state.isSetUp, isFalse);
    expect(child.online, isFalse);
  });

  group('app shell', () {
    Future<(FamilyStore, NoPushService)> pumpOnlineChild(WidgetTester tester, {String? at}) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final child = phone('parent-uid');
      await tester.runAsync(() => child.completeParentSetup(childName: 'Mia', pin: '1234'));
      final fake = AppServices.fake();
      final push = fake.push as NoPushService..fakeToken = 'fid-123';
      await tester.pumpWidget(FamilyCallApp(store: child, services: fake, initialLocation: at));
      await tester.runAsync(settle);
      await tester.pumpAndSettle();
      return (child, push);
    }

    testWidgets('the device registers its push id once it is online', (tester) async {
      final (child, _) = await pumpOnlineChild(tester);
      final user = await tester.runAsync(() => db.doc('users/parent-uid').get());
      expect(user!.data()!['fids'], ['fid-123']);
      expect(child.online, isTrue);
    });

    testWidgets('a call push opens the ringing screen with the caller\'s name', (tester) async {
      final (child, push) = await pumpOnlineChild(tester);
      push.fake.add({'type': 'call', 'familyId': child.state.familyId!, 'contactId': 'g', 'callId': 'c1'});
      await tester.pumpAndSettle();
      expect(find.text('Grandma'), findsOneWidget);
      expect(find.text('is calling…'), findsOneWidget);
    });

    testWidgets('pushes for another family are ignored', (tester) async {
      final (_, push) = await pumpOnlineChild(tester);
      push.fake.add({'type': 'call', 'familyId': 'someone-else', 'contactId': 'g'});
      await tester.pumpAndSettle();
      expect(find.text('is calling…'), findsNothing);
    });

    testWidgets('online, the chat sends to the server and no demo reply appears', (tester) async {
      final (child, _) = await pumpOnlineChild(tester, at: '/chat/g');
      await tester.tap(find.byKey(const Key('stickers')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sticker-cat')));
      await tester.runAsync(settle);
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(settle);
      final docs = await tester.runAsync(
        () => db.collection('families/${child.state.familyId}/threads/g/messages').get(),
      );
      expect(docs!.docs.map((d) => d['data']), ['cat']);
      expect(child.messagesWith('g'), hasLength(1), reason: 'no fake reply when a real person is on the other end');
    });
  });
}

class _SlowUploader extends FakeUploader {
  @override
  Future<String> upload(String localPath, String remotePath, String contentType) async {
    await Future<void>.delayed(const Duration(milliseconds: 200)); // a big file on a slow network
    return super.upload(localPath, remotePath, contentType);
  }
}
