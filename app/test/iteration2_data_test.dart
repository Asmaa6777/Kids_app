import 'dart:convert';
import 'dart:typed_data';

import 'package:family_call/data/family_repository.dart';
import 'package:family_call/data/family_store.dart';
import 'package:family_call/data/models.dart';
import 'package:family_call/logic/invite_code.dart';
import 'package:family_call/logic/pin.dart';
import 'package:family_call/logic/quiet_hours.dart';
import 'package:family_call/theme/colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PIN hashing', () {
    test('PBKDF2 matches a reference value computed with Python hashlib', () {
      final key = PinHasher.pbkdf2Sha256(utf8.encode('1234'), utf8.encode('familycall-salt'), 1000, 32);
      expect(
        key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '129bc912d8c8bce1cf4f07fc2a0e3a3a0e7f3e6736b303406cf602be7c588988',
      );
    });

    test('verify accepts the right PIN and rejects others', () {
      final stored = PinHasher.hash('2468');
      expect(PinHasher.verify('2468', stored), isTrue);
      expect(PinHasher.verify('2469', stored), isFalse);
      expect(PinHasher.verify('2468', null), isFalse);
      expect(stored, isNot(contains('2468')));
    });

    test('same PIN gets a different hash on each device (random salt)', () {
      expect(PinHasher.hash('1111'), isNot(PinHasher.hash('1111')));
      final salt = Uint8List(16);
      expect(PinHasher.hash('1111', salt: salt), PinHasher.hash('1111', salt: salt));
    });
  });

  group('quiet hours', () {
    const overnight = AppSettings(quietOn: true, quietFromMinutes: 20 * 60, quietToMinutes: 7 * 60);
    DateTime at(int h, int m) => DateTime(2026, 1, 1, h, m);

    test('window that crosses midnight', () {
      expect(isQuietTime(overnight, at(21, 0)), isTrue);
      expect(isQuietTime(overnight, at(3, 0)), isTrue);
      expect(isQuietTime(overnight, at(7, 0)), isFalse);
      expect(isQuietTime(overnight, at(12, 0)), isFalse);
      expect(isQuietTime(overnight, at(19, 59)), isFalse);
    });

    test('daytime window (nap time)', () {
      const nap = AppSettings(quietOn: true, quietFromMinutes: 13 * 60, quietToMinutes: 15 * 60);
      expect(isQuietTime(nap, at(14, 0)), isTrue);
      expect(isQuietTime(nap, at(15, 0)), isFalse);
    });

    test('off means never quiet', () {
      expect(isQuietTime(const AppSettings(), at(23, 0)), isFalse);
    });

    test('formatMinutes', () => expect(formatMinutes(7 * 60 + 5), '07:05'));
  });

  test('invite codes use only the friendly alphabet', () {
    for (var i = 0; i < 200; i++) {
      final code = generateInviteCode();
      expect(code, hasLength(6));
      expect(code.split('').every(inviteAlphabet.contains), isTrue);
    }
  });

  test('FamilyState survives a JSON round trip', () {
    final s = FamilyState.demo().copyWith(
      childName: 'Mia',
      role: Role.child,
      settings: const AppSettings(quietOn: true),
      messages: {
        'g': [ChatMessage(fromMe: true, type: MessageType.sticker, data: 'heart', sentAt: DateTime(2026))],
      },
      invites: [Invite(code: 'ABCDEF', createdAt: DateTime(2026))],
    );
    final back = FamilyState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
    expect(back.childName, 'Mia');
    expect(back.role, Role.child);
    expect(back.settings.quietOn, isTrue);
    expect(back.contacts.map((c) => c.name), s.contacts.map((c) => c.name));
    expect(back.messages['g']!.single.data, 'heart');
    expect(back.invites.single.code, 'ABCDEF');
    expect(back.unread, {'g', 'u'});
  });

  group('FamilyStore', () {
    late InMemoryFamilyRepository repo;
    late FamilyStore store;
    var clock = DateTime(2026, 1, 1, 12);

    setUp(() {
      repo = InMemoryFamilyRepository();
      clock = DateTime(2026, 1, 1, 12);
      store = FamilyStore(repo, repo.state, clock: () => clock);
    });

    test('parent setup stores a hash, not the PIN, and saves', () {
      store.completeParentSetup(childName: 'Mia', pin: '1234');
      expect(store.state.isSetUp, isTrue);
      expect(store.state.role, Role.child);
      expect(store.checkPin('1234'), isTrue);
      expect(store.checkPin('0000'), isFalse);
      expect(repo.state.pinHash, isNot(contains('1234')));
      expect(repo.saves, greaterThan(0));
      expect(store.state.activity.first.text, 'Device set up');
    });

    test('invite codes are per contact, single-use, and expire after 48 h (offline mode)', () async {
      final invite = await store.createInvite('g');
      expect(invite.contactId, 'g');
      final code = invite.code;
      expect(await store.joinFamily(code: code.toLowerCase(), name: 'Grandma', color: FamilyColor.coral), isNull);
      expect(store.state.role, Role.family);
      expect(store.state.invites.first.usedBy, 'Grandma');
      expect(await store.joinFamily(code: code, name: 'Someone', color: FamilyColor.blue), isNotNull);

      final old = (await store.createInvite('u')).code;
      clock = clock.add(const Duration(hours: 49));
      expect(await store.joinFamily(code: old, name: 'Late', color: FamilyColor.blue), contains('not valid'));
    });

    test('join needs a name; demo code always works', () async {
      expect(await store.joinFamily(code: 'KIDS42', name: '  ', color: FamilyColor.coral), 'Please type your name');
      expect(await store.joinFamily(code: 'KIDS42', name: 'Omar', color: FamilyColor.blue), isNull);
    });

    test('add, move and remove contacts', () {
      store.addContact('Cousin Sara', FamilyColor.green);
      expect(store.state.contacts.last.name, 'Cousin Sara');
      final id = store.state.contacts.last.id;
      store.moveContact(id, -1);
      expect(store.state.contacts[store.state.contacts.length - 2].id, id);
      store.moveContact(store.state.contacts.first.id, -1); // already first: no-op
      store.removeContact(id);
      expect(store.state.contacts.any((c) => c.id == id), isFalse);
    });

    test('quiet only applies to the child role', () {
      store.updateSettings(const AppSettings(quietOn: true, quietFromMinutes: 11 * 60, quietToMinutes: 13 * 60));
      store.switchRole(Role.family);
      expect(store.isQuiet, isFalse);
      store.switchRole(Role.child);
      expect(store.isQuiet, isTrue);
    });

    test('messages: sending logs it, receiving marks unread, reading clears it', () {
      store.markRead('g');
      store.sendMessage('g', ChatMessage(fromMe: true, type: MessageType.sticker, data: 'star', sentAt: clock));
      expect(store.state.activity.first.text, 'Sent a sticker to Grandma');
      expect(store.state.unread.contains('g'), isFalse);
      store.sendMessage('g', ChatMessage(fromMe: false, type: MessageType.voice, sentAt: clock));
      expect(store.state.unread.contains('g'), isTrue);
      expect(store.messagesWith('g'), hasLength(2));
    });
  });

  test('LocalFamilyRepository saves and loads through SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalFamilyRepository();
    expect((await repo.load()).contacts, hasLength(6)); // first launch → demo family
    await repo.save(FamilyState.demo().copyWith(childName: 'Mia'));
    expect((await repo.load()).childName, 'Mia');
  });
}
