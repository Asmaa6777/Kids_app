import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../services/speaker.dart';
import '../../theme/colors.dart';
import '../../widgets/bubbly_button.dart';
import '../../widgets/family_avatar.dart';
import 'parent_gate_corner.dart';

/// The child's home screen (design page 1): one big tile per family member.
///
/// * Tap a tile → the name is spoken aloud, then the person screen opens.
/// * Hold the invisible top-left corner for 3 s → parent PIN screen.
/// * During quiet hours, tiles are disabled and a "Sleepy time" card shows.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FamilyStore>();
    final state = store.state;
    final quiet = store.isQuiet;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GridView.count(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
              crossAxisCount: 2,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
              childAspectRatio: 0.82,
              children: [
                for (final c in state.contacts)
                  BubblyButton(
                    key: Key('tile-${c.id}'),
                    semanticLabel: c.name,
                    color: c.color,
                    onPressed: quiet
                        ? null
                        : () {
                            context.read<Speaker>().say(c.name);
                            context.push('/person/${c.id}');
                          },
                    padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
                    child: Column(
                      children: [
                        Expanded(
                          child: FittedBox(
                            child: FamilyAvatar(ring: Colors.white, size: 120, unread: state.unread.contains(c.id)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FittedBox(child: Text(c.name, style: Theme.of(context).textTheme.titleLarge, maxLines: 1)),
                      ],
                    ),
                  ),
              ],
            ),
            ParentGateCorner(onOpened: () => context.push('/gate')),
            if (quiet) const Positioned(left: 16, right: 16, bottom: 24, child: _SleepyCard()),
          ],
        ),
      ),
    );
  }
}

class _SleepyCard extends StatelessWidget {
  const _SleepyCard();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('sleepy'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.night, borderRadius: BorderRadius.circular(36)),
    child: const Column(
      children: [
        Icon(Icons.bedtime_rounded, size: 56, color: Colors.white),
        Text(
          'Sleepy time',
          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
        ),
        Text('See you in the morning!', style: TextStyle(color: Colors.white)),
      ],
    ),
  );
}
