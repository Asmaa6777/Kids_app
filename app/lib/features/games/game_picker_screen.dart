import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../services/speaker.dart';
import '../../theme/colors.dart';
import '../../widgets/bubbly_button.dart';
import 'game_widgets.dart';

/// Design page 6: choose a game.
class GamePickerScreen extends StatelessWidget {
  const GamePickerScreen({super.key, required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<FamilyStore>().contact(contactId);
    final games = [
      ('ttt', 'Tic-tac-toe', Icons.grid_3x3_rounded, FamilyColor.purple),
      ('memory', 'Memory', Icons.style_rounded, FamilyColor.green),
      ('count', 'Count with me', Icons.filter_9_plus_rounded, FamilyColor.coral),
    ];
    return GameFrame(
      title: c == null ? "Let's play" : 'Play with ${c.name}',
      fallback: contactId == 'child' ? '/family' : '/person/$contactId',
      child: ListView(
        children: [
          for (final (id, label, icon, color) in games)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BubblyButton(
                key: Key('game-$id'),
                color: color,
                borderRadius: BorderRadius.circular(52),
                padding: const EdgeInsets.all(14),
                semanticLabel: label,
                onPressed: () {
                  context.read<Speaker>().say(label);
                  context.push('/games/$contactId/$id');
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.white,
                      child: Icon(icon, size: 50, color: AppColors.ink),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(label, style: const TextStyle(fontSize: 34)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
