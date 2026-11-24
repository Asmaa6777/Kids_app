import 'package:family_call/app/app.dart';
import 'package:family_call/widgets/bubbly_button.dart';
import 'package:family_call/widgets/family_avatar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('app starts on the welcome screen', (tester) async {
    await tester.pumpWidget(const FamilyCallApp());
    expect(find.text('Family Call'), findsOneWidget);
    expect(find.text('Set up for my child'), findsOneWidget);
    expect(find.text('Join my family'), findsOneWidget);
  });

  testWidgets('tapping "Set up for my child" navigates to /setup', (tester) async {
    await tester.pumpWidget(const FamilyCallApp());
    await tester.tap(find.byKey(const Key('choose-parent')));
    await tester.pumpAndSettle();
    expect(find.text('Parent setup'), findsOneWidget);
  });

  testWidgets('home shows one tile per family member', (tester) async {
    await tester.pumpWidget(const FamilyCallApp(initialLocation: '/home'));
    expect(find.byType(FamilyAvatar), findsNWidgets(4));
    expect(find.text('Grandma'), findsOneWidget);
  });

  testWidgets('BubblyButton calls onPressed, and ignores taps when disabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Column(children: [
        BubblyButton(key: const Key('on'), onPressed: () => taps++, child: const Text('on')),
        const BubblyButton(key: Key('off'), onPressed: null, child: Text('off')),
      ]),
    ));
    await tester.tap(find.byKey(const Key('on')));
    await tester.tap(find.byKey(const Key('off')));
    expect(taps, 1);
  });

  testWidgets('avatar shows the unread dot only when unread', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Row(children: [FamilyAvatar(ring: Colors.red, unread: true), FamilyAvatar(ring: Colors.red)]),
    ));
    expect(find.byKey(const Key('unread-dot')), findsOneWidget);
  });
}
