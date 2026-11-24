import 'dart:math';

/// Tic-tac-toe rules, with no UI, so it is easy to test.
///
/// The board is 9 cells, index = row * 3 + col:
///   0 | 1 | 2
///   3 | 4 | 5
///   6 | 7 | 8
class TicTacToe {
  final List<String?> cells = List.filled(9, null);

  static const lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
    [0, 4, 8], [2, 4, 6], //           diagonals
  ];

  /// 'X' or 'O' if someone has three in a row, otherwise null.
  String? get winner {
    for (final l in lines) {
      final a = cells[l[0]];
      if (a != null && a == cells[l[1]] && a == cells[l[2]]) return a;
    }
    return null;
  }

  bool get isDraw => winner == null && cells.every((c) => c != null);
  bool get isOver => winner != null || isDraw;

  bool play(int index, String mark) {
    if (isOver || cells[index] != null) return false;
    cells[index] = mark;
    return true;
  }

  /// A friendly opponent for the demo: win if it can, block if it must,
  /// otherwise centre, then a random free cell. It can be beaten.
  int bestMove(String me, String them, [Random? random]) {
    int? finish(String mark) {
      for (final l in lines) {
        final marks = l.map((i) => cells[i]).toList();
        if (marks.where((m) => m == mark).length == 2 && marks.contains(null)) return l[marks.indexOf(null)];
      }
      return null;
    }

    final free = [
      for (var i = 0; i < 9; i++)
        if (cells[i] == null) i,
    ];
    return finish(me) ?? finish(them) ?? (cells[4] == null ? 4 : free[(random ?? Random()).nextInt(free.length)]);
  }
}
