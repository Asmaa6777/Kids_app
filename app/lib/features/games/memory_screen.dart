import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../logic/memory_game.dart';
import '../../services/speaker.dart';
import '../../theme/colors.dart';
import '../../widgets/bubbly_button.dart';
import '../../widgets/sticker.dart';
import 'game_widgets.dart';

/// Memory match with the sticker pictures (6 pairs = 12 cards).
/// Each matched picture is spoken ("Sun!"), so it also teaches words.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key, required this.contactId});

  final String contactId;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  late MemoryGame _game = _newGame();
  Timer? _hide;

  static MemoryGame _newGame() => MemoryGame(Sticker.values.take(6).map((s) => s.name).toList());

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _flip(int i) {
    final result = _game.flip(i);
    setState(() {});
    final speaker = context.read<Speaker>();
    switch (result) {
      case FlipResult.match:
        speaker.say(_game.isWon ? 'You found them all!' : '${_game.cards[i]}!');
      case FlipResult.mismatch:
        _hide = Timer(const Duration(milliseconds: 900), () {
          if (mounted) setState(_game.hideMismatch);
        });
      case FlipResult.first || FlipResult.ignored:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Memory',
      fallback: '/games/${widget.contactId}',
      trailing: Text('${_game.moves}', key: const Key('moves'), style: const TextStyle(fontSize: 24)),
      child: Column(
        children: [
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3 / 4,
              children: [
                for (var i = 0; i < _game.cards.length; i++)
                  BubblyButton(
                    key: Key('card-$i'),
                    color: _game.isFaceUp(i) ? FamilyColor.white : FamilyColor.green,
                    borderRadius: BorderRadius.circular(22),
                    depth: 6,
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _flip(i),
                    child: Center(
                      child: _game.isFaceUp(i)
                          ? FittedBox(child: StickerView(Sticker.byName(_game.cards[i]), size: 80))
                          : const Icon(Icons.question_mark_rounded, size: 36, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          if (_game.isWon) ...[
            const Celebration(text: 'All pairs!'),
            BubblyButton(
              key: const Key('again'),
              color: FamilyColor.green,
              onPressed: () => setState(() => _game = _newGame()),
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
