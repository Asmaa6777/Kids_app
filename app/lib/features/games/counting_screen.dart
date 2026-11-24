import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../logic/counting.dart';
import '../../services/speaker.dart';
import '../../theme/colors.dart';
import '../../widgets/bubbly_button.dart';
import '../../widgets/sticker.dart';
import 'game_widgets.dart';

/// First learning game: "Count with me".
///
/// Shows 1–10 stickers; the child taps the matching number. Every answer is
/// spoken, and a wrong answer is never "wrong", only "let's count again".
class CountingScreen extends StatefulWidget {
  const CountingScreen({super.key, required this.contactId});

  final String contactId;

  @override
  State<CountingScreen> createState() => _CountingScreenState();
}

class _CountingScreenState extends State<CountingScreen> {
  CountingRound _round = CountingRound.random();
  Sticker _sticker = Sticker.star;
  int _stars = 0;
  bool _solved = false;

  void _answer(int n) {
    final speaker = context.read<Speaker>();
    if (_round.check(n)) {
      speaker.say('${numberWords[n]}! Well done!');
      setState(() {
        _stars++;
        _solved = true;
      });
    } else {
      speaker.say("Let's count again!");
    }
  }

  void _next() => setState(() {
    _round = CountingRound.random();
    _sticker = Sticker.values[(_stars + _round.target) % Sticker.values.length];
    _solved = false;
  });

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Count with me',
      fallback: '/games/${widget.contactId}',
      trailing: Row(
        children: [
          Icon(Icons.star_rounded, color: FamilyColor.yellow.main, size: 32),
          Text('$_stars', key: const Key('stars'), style: const TextStyle(fontSize: 24)),
        ],
      ),
      child: Column(
        children: [
          const Text('How many?', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < _round.target; i++)
                    GestureDetector(
                      // Tapping an item counts it out loud: "one, two, three…"
                      onTap: () => context.read<Speaker>().say(numberWords[i + 1]),
                      child: StickerView(_sticker, key: Key('count-item-$i'), size: 64),
                    ),
                ],
              ),
            ),
          ),
          if (_solved) ...[
            Celebration(text: '${_round.target}!'),
            const SizedBox(height: 8),
            BubblyButton(
              key: const Key('next-round'),
              color: FamilyColor.green,
              onPressed: _next,
              child: const Center(child: Icon(Icons.arrow_forward_rounded, size: 40)),
            ),
          ] else
            Row(
              children: [
                for (final n in _round.choices)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: BubblyButton(
                        key: Key('answer-$n'),
                        color: FamilyColor.coral,
                        semanticLabel: '$n',
                        onPressed: () => _answer(n),
                        child: Center(
                          child: Text('$n', style: const TextStyle(fontSize: 44, color: AppColors.ink)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
