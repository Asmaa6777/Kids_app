import 'package:family_call/data/models.dart';
import 'package:family_call/features/chat/drawing.dart';
import 'package:family_call/services/voice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  group('chat', () {
    testWidgets('opening a chat clears the unread dot', (tester) async {
      final h = Harness(setUpChild());
      expect(h.store.state.unread, contains('g'));
      await h.pump(tester, at: '/chat/g');
      expect(h.store.state.unread, isNot(contains('g')));
      expect(find.text('Say hello!'), findsOneWidget);
    });

    testWidgets('sending a sticker shows it, and the demo reply arrives 2 s later', (tester) async {
      final h = Harness(setUpChild());
      await h.pump(tester, at: '/chat/g');

      await tester.tap(find.byKey(const Key('stickers')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sticker-star')));
      await tester.pump();
      expect(h.store.messagesWith('g').single.data, 'star');

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      final msgs = h.store.messagesWith('g');
      expect(msgs, hasLength(2));
      expect(msgs.last.fromMe, isFalse);
      expect(h.store.state.unread, isNot(contains('g'))); // we were looking at it
    });

    testWidgets('typing is hidden for the child until the parent allows it', (tester) async {
      final h = Harness(setUpChild());
      await h.pump(tester, at: '/chat/g');
      expect(find.byKey(const Key('text-input')), findsNothing);

      h.store.updateSettings(h.store.state.settings.copyWith(typingAllowed: true));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('text-input')), 'Hi Grandma');
      await tester.tap(find.byKey(const Key('text-send')));
      await tester.pumpAndSettle();
      expect(find.text('Hi Grandma'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // flush the demo reply timer
    });

    testWidgets('hold to talk records a voice note; a quick tap does not', (tester) async {
      final h = Harness(setUpChild());
      await h.pump(tester, at: '/chat/g');
      final talk = find.byKey(const Key('talk'));

      await tester.tap(talk); // too short
      await tester.pumpAndSettle();
      expect(h.store.messagesWith('g'), isEmpty);

      // Stopwatch measures real time, so hold for real (runAsync leaves fake time).
      final gesture = await tester.startGesture(tester.getCenter(talk));
      await tester.pump();
      expect(find.text('Listening…'), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await gesture.up();
      await tester.pumpAndSettle();

      final note = h.store.messagesWith('g').single;
      expect(note.type, MessageType.voice);
      expect(note.data, 'fake-voice.m4a');
      expect(find.byKey(const Key('voice-bubble')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      expect((h.services.player as FakeVoicePlayer).played, ['fake-voice.m4a']);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('drawing: send is disabled until you draw; the stroke is saved', (tester) async {
      final h = Harness(setUpChild());
      await h.pump(tester, at: '/chat/g');

      await tester.tap(find.byKey(const Key('draw')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('draw-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draw-canvas')), findsOneWidget); // still open: nothing to send

      await tester.tap(find.byKey(const Key('ink-1')));
      await tester.drag(find.byKey(const Key('draw-canvas')), const Offset(120, 80));
      await tester.pump();
      await tester.tap(find.byKey(const Key('draw-send')));
      await tester.pumpAndSettle();

      final msg = h.store.messagesWith('g').single;
      expect(msg.type, MessageType.drawing);
      final strokes = Stroke.decode(msg.data);
      expect(strokes, hasLength(1));
      expect(strokes.single.color, DrawingPad.inks[1]);
      expect(strokes.single.points.length, greaterThan(1));
      expect(strokes.single.points.every((p) => p.dx >= 0 && p.dx <= 1 && p.dy >= 0 && p.dy <= 1), isTrue);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  test('strokes survive encode → decode', () {
    final s = [
      Stroke(const Color(0xFFFF0000), [const Offset(0.1, 0.2), const Offset(0.3333, 0.9)]),
    ];
    final back = Stroke.decode(Stroke.encode(s));
    expect(back.single.color, const Color(0xFFFF0000));
    expect(back.single.points.last, const Offset(0.333, 0.9)); // rounded to 3 decimals
    expect(Stroke.decode('not json'), isEmpty);
  });

  group('parent area', () {
    Future<Harness> openParent(WidgetTester tester) async {
      final h = Harness(setUpChild());
      await h.pump(tester, at: '/parent');
      return h;
    }

    testWidgets('add a contact → it appears on the child home', (tester) async {
      final h = await openParent(tester);
      await tester.tap(find.byKey(const Key('add-contact')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('new-contact-name')), 'Cousin Sara');
      await tester.tap(find.byKey(const Key('confirm-add')));
      await tester.pumpAndSettle();
      expect(h.store.state.contacts.last.name, 'Cousin Sara');
      expect(find.text('Cousin Sara'), findsOneWidget);
    });

    testWidgets('remove asks first, then removes', (tester) async {
      final h = await openParent(tester);
      await tester.tap(find.byKey(const Key('delete-g')));
      await tester.pumpAndSettle();
      expect(find.text('Remove Grandma?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-remove')));
      await tester.pumpAndSettle();
      expect(h.store.contact('g'), isNull);
    });

    testWidgets('reorder: first item cannot move up; down swaps', (tester) async {
      final h = await openParent(tester);
      final upFirst = tester.widget<IconButton>(find.byKey(const Key('up-g')));
      expect(upFirst.onPressed, isNull);
      await tester.tap(find.byKey(const Key('down-g')));
      await tester.pumpAndSettle();
      expect(h.store.state.contacts[1].id, 'g');
    });

    testWidgets('new invite code is shown; quiet hours toggle reveals the times', (tester) async {
      final h = await openParent(tester);
      await tester.tap(find.byKey(const Key('new-invite')));
      await tester.pumpAndSettle();
      final code = h.store.state.invites.first.code;
      expect(find.text(code), findsOneWidget);
      expect(find.text('Waiting'), findsOneWidget);

      await tester.scrollUntilVisible(find.byKey(const Key('toggle-quiet')), 200);
      await tester.ensureVisible(find.byKey(const Key('toggle-quiet'))); // fully on screen, not just a sliver
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle-quiet')));
      await tester.pumpAndSettle();
      expect(h.store.state.settings.quietOn, isTrue);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
    });

    testWidgets('change PIN: two matching entries replace the old PIN', (tester) async {
      final h = await openParent(tester);
      await tester.scrollUntilVisible(find.byKey(const Key('change-pin')), 200);
      await tester.ensureVisible(find.byKey(const Key('change-pin'))); // fully on screen, not just a sliver
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('change-pin')));
      await tester.pumpAndSettle();
      await typePin(tester, '5678');
      await typePin(tester, '5678');
      expect(h.store.checkPin('5678'), isTrue);
      expect(h.store.checkPin('1234'), isFalse);
      expect(find.text('New PIN'), findsNothing); // dialog closed
    });

    testWidgets('"Lock & exit" pins the app again and goes home', (tester) async {
      final h = await openParent(tester);
      await tester.tap(find.byKey(const Key('back-to-child')));
      await tester.pumpAndSettle();
      expect(h.kiosk.locked, isTrue);
      expect(find.byKey(const Key('tile-g')), findsOneWidget);
    });
  });
}
