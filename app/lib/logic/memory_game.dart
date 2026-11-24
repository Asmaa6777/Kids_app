import 'dart:math';

/// Memory match: find the pairs.
///
/// Flow for each turn: flip one card, flip a second.
///   * Same picture → both stay face up ([matched]).
///   * Different → [flip] returns [FlipResult.mismatch]; the UI waits a moment
///     so the child can see them, then calls [hideMismatch].
enum FlipResult { ignored, first, match, mismatch }

class MemoryGame {
  MemoryGame(List<String> pictures, {Random? random}) : cards = [...pictures, ...pictures]..shuffle(random);

  final List<String> cards;
  final Set<int> matched = {};
  final List<int> open = []; // face-up cards that are not matched yet (0, 1 or 2)
  int moves = 0;

  bool get isWon => matched.length == cards.length;
  bool isFaceUp(int i) => matched.contains(i) || open.contains(i);

  FlipResult flip(int i) {
    if (open.length == 2 || isFaceUp(i)) return FlipResult.ignored;
    open.add(i);
    if (open.length == 1) return FlipResult.first;
    moves++;
    if (cards[open[0]] == cards[open[1]]) {
      matched.addAll(open);
      open.clear();
      return FlipResult.match;
    }
    return FlipResult.mismatch;
  }

  void hideMismatch() => open.clear();
}
