import 'package:family_call/app/app.dart';
import 'package:family_call/data/family_repository.dart';
import 'package:family_call/data/family_store.dart';
import 'package:family_call/data/models.dart';
import 'package:family_call/services/kiosk.dart';
import 'package:family_call/services/speaker.dart';
import 'package:family_call/theme/colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Everything a test needs: the app plus handles on its fakes.
class Harness {
  Harness([FamilyState? initial]) {
    final repo = InMemoryFamilyRepository(initial);
    store = FamilyStore(repo, repo.state, clock: () => now);
  }

  late final FamilyStore store;
  final speaker = RecordingSpeaker();
  final kiosk = FakeKiosk();
  DateTime now = DateTime(2026, 1, 1, 12);

  Future<void> pump(WidgetTester tester, {String? at}) async {
    // A phone-sized screen (400×900 logical pixels) instead of the 800×600 default.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FamilyCallApp(store: store, speaker: speaker, kiosk: kiosk, initialLocation: at));
    await tester.pumpAndSettle();
  }
}

Future<void> typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.byKey(Key('pin-$d')));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

FamilyState setUpChild({AppSettings settings = const AppSettings()}) {
  final repo = InMemoryFamilyRepository();
  final s = FamilyStore(repo, repo.state)..completeParentSetup(childName: 'Mia', pin: '1234');
  return s.state.copyWith(settings: settings);
}

void main() {
  testWidgets('parent setup: name → PIN → mismatch → PIN ×2 → checklist → pinned home', (tester) async {
    final h = Harness();
    await h.pump(tester);

    await tester.tap(find.byKey(const Key('choose-parent')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('next')));
    await tester.pump();
    expect(find.text('Please type a name'), findsOneWidget); // empty name is refused

    await tester.enterText(find.byKey(const Key('child-name')), 'Mia');
    await tester.tap(find.byKey(const Key('next')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a parent PIN'), findsOneWidget);

    await typePin(tester, '1234');
    expect(find.text('Type it again'), findsOneWidget);
    await typePin(tester, '9999');
    expect(find.text("PINs don't match — try again"), findsOneWidget);
    expect(h.store.state.isSetUp, isFalse);

    await typePin(tester, '1234');
    await tester.pump(const Duration(seconds: 5)); // let the "don't match" snackbar time out
    await tester.pumpAndSettle();
    expect(find.text('Almost done!'), findsOneWidget);
    expect(h.store.state.childName, 'Mia');
    expect(h.store.checkPin('1234'), isTrue);

    await tester.ensureVisible(find.byKey(const Key('start')));
    await tester.pumpAndSettle(); // let the scroll finish before tapping
    await tester.tap(find.byKey(const Key('start')));
    await tester.pumpAndSettle();
    expect(h.kiosk.locked, isTrue);
    expect(find.byKey(const Key('tile-g')), findsOneWidget);
  });

  testWidgets('join: bad code is refused, demo code opens the relative view', (tester) async {
    final h = Harness();
    await h.pump(tester, at: '/join');

    await tester.enterText(find.byKey(const Key('code')), 'ZZZZZZ');
    await tester.enterText(find.byKey(const Key('name')), 'Grandma');
    await tester.tap(find.byKey(const Key('join')));
    await tester.pump();
    expect(find.text('That code is not valid or was already used'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('code')), 'kids42');
    await tester.tap(find.byKey(const Key('color-green')));
    await tester.tap(find.byKey(const Key('join')));
    await tester.pumpAndSettle();
    expect(find.text('Signed in as'), findsOneWidget);
    expect(find.text('Grandma'), findsOneWidget);
    expect(h.store.state.me!.color.name, 'green');
  });

  testWidgets('tapping a tile says the name and opens Call / Message / Play', (tester) async {
    final h = Harness(setUpChild());
    await h.pump(tester);

    await tester.tap(find.byKey(const Key('tile-g')));
    await tester.pumpAndSettle();
    expect(h.speaker.said, ['Grandma']);
    expect(find.byKey(const Key('call')), findsOneWidget);
    expect(find.byKey(const Key('message')), findsOneWidget);
    expect(find.byKey(const Key('play')), findsOneWidget);

    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-g')), findsOneWidget);
  });

  testWidgets('parent gate: a short tap does nothing; a 3-second hold + right PIN opens the parent area', (
    tester,
  ) async {
    final h = Harness(setUpChild());
    h.kiosk.locked = true;
    await h.pump(tester);

    final corner = find.byKey(const Key('parent-gate'));
    await tester.tap(corner);
    await tester.pumpAndSettle();
    expect(find.text('Grown-ups only'), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(corner));
    await tester.pump(); // first frame starts the hold animation's clock
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Grown-ups only'), findsNothing); // 1 s is not enough
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Grown-ups only'), findsOneWidget);

    await typePin(tester, '0000');
    expect(find.text('Grown-ups only'), findsOneWidget); // wrong PIN: still locked
    expect(h.kiosk.locked, isTrue);

    await typePin(tester, '1234');
    expect(find.text('Parent area'), findsOneWidget);
    expect(h.kiosk.locked, isFalse);
  });

  testWidgets('quiet hours: tiles are disabled and "Sleepy time" shows', (tester) async {
    final h = Harness(
      setUpChild(
        settings: const AppSettings(quietOn: true, quietFromMinutes: 11 * 60, quietToMinutes: 13 * 60),
      ),
    );
    await h.pump(tester);

    expect(find.byKey(const Key('sleepy')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tile-g')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('call')), findsNothing);
    expect(h.speaker.said, isEmpty);
  });

  testWidgets('app opens on the right screen for each role', (tester) async {
    final relative = setUpChild().copyWith(
      role: Role.family,
      me: const Contact(id: 'me', name: 'Omar', color: FamilyColor.blue),
    );
    final h = Harness(relative);
    await h.pump(tester);
    expect(find.text('Signed in as'), findsOneWidget);
  });
}
