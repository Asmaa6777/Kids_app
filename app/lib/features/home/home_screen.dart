import 'package:material_ui/material_ui.dart';

import '../../theme/colors.dart';
import '../../widgets/bubbly_button.dart';
import '../../widgets/family_avatar.dart';

/// The child's home screen (design page 1): one big tile per family member.
///
/// Iteration 1 uses fixed demo contacts. Iteration 2 loads them from a repository.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _demo = [
    ('Grandma', FamilyColor.coral),
    ('Grandpa', FamilyColor.yellow),
    ('Aunt Dina', FamilyColor.green),
    ('Uncle Omar', FamilyColor.blue),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GridView.count(
          padding: const EdgeInsets.all(20),
          crossAxisCount: 2,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          childAspectRatio: 0.82,
          children: [
            for (final (name, color) in _demo)
              BubblyButton(
                key: Key('tile-$name'),
                semanticLabel: name,
                color: color,
                onPressed: () {},
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
                child: Column(
                  children: [
                    const Expanded(child: FittedBox(child: FamilyAvatar(ring: Colors.white, size: 120))),
                    const SizedBox(height: 10),
                    Text(name, style: Theme.of(context).textTheme.titleLarge, maxLines: 1),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
