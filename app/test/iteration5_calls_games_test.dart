import 'dart:math';

import 'package:family_call/logic/counting.dart';
import 'package:family_call/logic/memory_game.dart';
import 'package:family_call/logic/tic_tac_toe.dart';
import 'package:family_call/services/call_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  group('tic-tac-toe rules', () {
    TicTacToe board(String cells) {
      final g = TicTacToe();
      for (var i = 0; i < 9; i++) {
        if (cells[i] != '.') g.cells[i] = cells[i];
      }
      return g;
    }

    test('detects rows, columns and diagonals', () {
      expect(board('XXX......').winner, 'X');
      expect(board('O..O..O..').winner, 'O');
      expect(board('X...X...X').winner, 'X');
      expect(board('..O.O.O..').winner, 'O');
      expect(board('XX.......').winner, isNull);
    });

    test('draw when full with no winner', () {
      final g = board('XOXXOOOXX');
      expect(g.winner, isNull);
      expect(g.isDraw, isTrue);
    });

    test('cannot play on a taken cell or after the game ends', () {
      final g = board('XXX......');
      expect(g.play(5, 'O'), isFalse);
      expect(TicTacToe().play(0, 'X'), isTrue);
    });

    test('opponent wins when it can, otherwise blocks', () {
      expect(board('OO.XX....').bestMove('O', 'X'), 2); // finish its own row
      expect(board('XX..O....').bestMove('O', 'X'), 2); // block X
      expect(TicTacToe().bestMove('O', 'X', Random(1)), 4); // centre first
    });
  });

  group('memory rules', () {
    test('pairs match, mismatches hide, game is won when all match', () {
      final g = MemoryGame(['a', 'b'], random: Random(3));
      final a = [
        for (var i = 0; i < 4; i++)
          if (g.cards[i] == 'a') i,
      ];
      final b = [
        for (var i = 0; i < 4; i++)
          if (g.cards[i] == 'b') i,
      ];

      expect(g.flip(a[0]), FlipResult.first);
      expect(g.flip(a[0]), FlipResult.ignored); // same card again
      expect(g.flip(b[0]), FlipResult.mismatch);
      expect(g.flip(b[1]), FlipResult.ignored); // two already open
      g.hideMismatch();

      expect(g.flip(a[0]), FlipResult.first);
      expect(g.flip(a[1]), FlipResult.match);
      expect(g.flip(b[0]), FlipResult.first);
      expect(g.flip(b[1]), FlipResult.match);
      expect(g.isWon, isTrue);
      expect(g.moves, 3);
    });
  });

  test('counting rounds: 3 different choices in range, one of them right', () {
    final r = Random(7);
    for (var i = 0; i < 300; i++) {
      final round = CountingRound.random(random: r);
      expect(round.choices.toSet(), hasLength(3));
      expect(round.choices, contains(round.target));
      expect(round.choices.every((n) => n >= 1 && n <= 10), isTrue);
      expect(round.check(round.target), isTrue);
    }
  });

  group('calls', () {
    testWidgets('demo call: "Calling…", then connected with a timer; hang up logs it', (tester) async {
      final h = Harness(setUpChild());
      await h.pump(tester, at: '/person/g');
      await tester.tap(find.byKey(const Key('call')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Calling…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2)); // the demo "answers"
      await tester.pump(const Duration(seconds: 61));
      expect(find.text('1:01'), findsOneWidget);

      final session = (h.services.calls as DemoCallService).last!;
      await tester.tap(find.byKey(const Key('mic')));
      await tester.pump();
      expect(session.micOn, isFalse);
      await tester.tap(find.byKey(const Key('flip')));
      expect(session.flips, 1);

      await tester.tap(find.byKey(const Key('hangup')));
      await tester.pumpAndSettle();
      expect(session.ended, isTrue);
      expect(h.store.state.activity.first.text, startsWith('Video call with Grandma'));
      expect(find.byKey(const Key('call')), findsOneWidget); // back on the person screen
    });

    testWidgets('face filters: shown when allowed, overlay appears; hidden when the parent turns them off', (
      tester,
    ) async {
      final h = Harness(setUpChild());
      await h.pump(tester, at: '/call/g');
      await tester.tap(find.byKey(const Key('filter-stars')));
      await tester.pump();
      expect(find.byKey(const Key('filter-overlay')), findsOneWidget);

      h.store.updateSettings(h.store.state.settings.copyWith(filtersAllowed: false));
      await tester.pump();
      expect(find.byKey(const Key('filter-stars')), findsNothing);
      await tester.tap(find.byKey(const Key('hangup')));
      await tester.pumpAndSettle();
    });

    testWidgets('incoming call announces the caller; answer opens the call', (tester) async {
      final h = Harness(setUpChild());
      await h.pump(tester, at: '/incoming/u');
      expect(h.speaker.said, contains('Uncle Omar is calling'));
      await tester.tap(find.byKey(const Key('accept')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('hangup')), findsOneWidget);
      await tester.tap(find.byKey(const Key('hangup')));
      await tester.pumpAndSettle();
    });
  });

  group('games', () {
    testWidgets('picker → tic-tac-toe: my X, then the opponent answers', (tester) async {
      final h = Harness(setUpChild());
      await h.pump(tester, at: '/games/g');
      await tester.tap(find.byKey(const Key('game-ttt')));
      await tester.pumpAndSettle();
      expect(find.text('Your turn!'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cell-0')));
      await tester.pump();
      expect(find.text("Grandma's turn…"), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Your turn!'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget); // the opponent took the centre
    });

    testWidgets('memory: two cards flip; a move is counted', (tester) async {
      final h = Harness(setUpChild());
      await h.pump(tester, at: '/games/g/memory');
      await tester.tap(find.byKey(const Key('card-0')));
      await tester.tap(find.byKey(const Key('card-1')));
      await tester.pump();
      expect(find.text('1'), findsOneWidget); // moves
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('count with me: count the stickers like a child, tap that number, earn a star', (tester) async {
      final h = Harness(setUpChild());
      await h.pump(tester, at: '/games/g/count');

      // A wrong answer first (if one exists among the buttons): gentle feedback, no star.
      final count = find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('count-item-'),
          )
          .evaluate()
          .length;
      final wrong = [
        for (var n = 1; n <= 10; n++)
          if (n != count) n,
      ].firstWhere((n) => find.byKey(Key('answer-$n')).evaluate().isNotEmpty);
      await tester.tap(find.byKey(Key('answer-$wrong')));
      await tester.pump();
      expect(h.speaker.said.last, "Let's count again!");
      expect(find.text('0'), findsOneWidget);

      await tester.tap(find.byKey(Key('answer-$count')));
      await tester.pump();
      expect(h.speaker.said.last, '${numberWords[count]}! Well done!');
      expect(find.byKey(const Key('celebration')), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // stars

      await tester.tap(find.byKey(const Key('next-round')));
      await tester.pump();
      expect(find.byKey(const Key('celebration')), findsNothing);
    });
  });
}
