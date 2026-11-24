import 'package:family_call/app/app.dart';
import 'package:family_call/data/family_repository.dart';
import 'package:family_call/data/family_store.dart';
import 'package:family_call/data/models.dart';
import 'package:family_call/services/app_services.dart';
import 'package:family_call/services/kiosk.dart';
import 'package:family_call/services/speaker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Everything a test needs: the app plus handles on its fakes.
class Harness {
  Harness([FamilyState? initial]) {
    final repo = InMemoryFamilyRepository(initial);
    store = FamilyStore(repo, repo.state, clock: () => now);
  }

  late final FamilyStore store;
  final services = AppServices.fake();
  RecordingSpeaker get speaker => services.speaker as RecordingSpeaker;
  FakeKiosk get kiosk => services.kiosk as FakeKiosk;
  DateTime now = DateTime(2026, 1, 1, 12);

  Future<void> pump(WidgetTester tester, {String? at}) async {
    // A phone-sized screen (400×900 logical pixels) instead of the 800×600 default.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FamilyCallApp(store: store, services: services, initialLocation: at));
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
