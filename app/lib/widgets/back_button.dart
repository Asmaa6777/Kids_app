import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'bubbly_button.dart';

/// Round white back button used at the top of child screens.
/// Goes to [fallback] when there is nothing to pop (e.g. opened from a link).
class RoundBackButton extends StatelessWidget {
  const RoundBackButton({super.key, required this.fallback, this.icon = Icons.arrow_back_rounded});

  final String fallback;
  final IconData icon;

  @override
  Widget build(BuildContext context) => BubblyButton.circle(
    key: const Key('back'),
    semanticLabel: 'Back',
    onPressed: () => context.canPop() ? context.pop() : context.go(fallback),
    child: Icon(icon, size: 34),
  );
}
