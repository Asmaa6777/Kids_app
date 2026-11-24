import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../widgets/bubbly_button.dart';
import '../../widgets/family_avatar.dart';

/// The child's home screen (design page 1): one big tile per family member.
///
/// Contacts come from the [FamilyStore], so parent edits show up immediately.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FamilyStore>().state;
    return Scaffold(
      body: SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.all(20),
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
                onPressed: () {},
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
                child: Column(
                  children: [
                    Expanded(
                      child: FittedBox(
                        child: FamilyAvatar(ring: Colors.white, size: 120, unread: state.unread.contains(c.id)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(c.name, style: Theme.of(context).textTheme.titleLarge, maxLines: 1),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
