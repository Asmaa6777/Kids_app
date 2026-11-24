import 'package:material_ui/material_ui.dart';

import '../../theme/colors.dart';
import '../../widgets/back_button.dart';

/// Shared frame for every game: back button, title, and the game area.
class GameFrame extends StatelessWidget {
  const GameFrame({super.key, required this.title, required this.fallback, required this.child, this.trailing});

  final String title;
  final String fallback;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                RoundBackButton(fallback: fallback),
                const SizedBox(width: 14),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

/// The big yellow star + message shown when a round is won.
class Celebration extends StatelessWidget {
  const Celebration({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('celebration'),
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.star_rounded, size: 84, color: FamilyColor.yellow.main),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
      ),
    ],
  );
}
