import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../logic/tic_tac_toe.dart';
import '../../services/speaker.dart';
import '../../theme/colors.dart';
import '../../widgets/bubbly_button.dart';
import 'game_widgets.dart';

/// Tic-tac-toe against the family member. Until the backend exists, their
/// moves come from [TicTacToe.bestMove] after a short "thinking" pause.
class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key, required this.contactId});

  final String contactId;

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  var _game = TicTacToe();
  bool _theirTurn = false;
  Timer? _think;

  @override
  void dispose() {
    _think?.cancel();
    super.dispose();
  }

  void _tap(int i) {
    if (_theirTurn || !_game.play(i, 'X')) return;
    setState(() {});
    if (_announce()) return;
    _theirTurn = true;
    _think = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _game.play(_game.bestMove('O', 'X'), 'O');
        _theirTurn = false;
      });
      _announce();
    });
  }

  /// Speaks the result if the game ended. Returns true when it did.
  bool _announce() {
    if (!_game.isOver) return false;
    final speaker = context.read<Speaker>();
    speaker.say(
      _game.winner == 'X'
          ? 'You win!'
          : _game.winner == 'O'
          ? 'Good game! Try again!'
          : "It's a tie!",
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<FamilyStore>().contact(widget.contactId);
    final over = _game.isOver;
    return GameFrame(
      title: 'Tic-tac-toe',
      fallback: '/games/${widget.contactId}',
      child: Column(
        children: [
          Text(
            over ? '' : (_theirTurn ? "${c?.name ?? 'Their'}'s turn…" : 'Your turn!'),
            key: const Key('turn'),
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1,
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < 9; i++)
                  BubblyButton(
                    key: Key('cell-$i'),
                    borderRadius: BorderRadius.circular(28),
                    depth: 7,
                    padding: const EdgeInsets.all(8),
                    onPressed: over || _game.cells[i] != null ? null : () => _tap(i),
                    child: Center(
                      child: switch (_game.cells[i]) {
                        'X' => Icon(Icons.close_rounded, size: 72, color: FamilyColor.blue.dark),
                        'O' => Icon(Icons.circle_outlined, size: 64, color: c?.color.dark ?? FamilyColor.coral.dark),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (over) ...[
            Celebration(text: _game.winner == 'X' ? 'You win!' : (_game.winner == 'O' ? 'Good game!' : "It's a tie!")),
            const SizedBox(height: 12),
            BubblyButton(
              key: const Key('again'),
              color: FamilyColor.green,
              onPressed: () => setState(() => _game = TicTacToe()),
              child: const Center(
                child: Text('Play again', style: TextStyle(fontSize: 24, color: AppColors.ink)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
