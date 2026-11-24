import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../data/models.dart';
import '../../theme/colors.dart';
import '../../widgets/bubbly_button.dart';
import '../../widgets/family_avatar.dart';

/// What a relative (grandma, uncle…) sees: the child, and Messages / Call / Play.
class FamilyView extends StatelessWidget {
  const FamilyView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FamilyStore>();
    final me = store.state.me;
    final kid = store.contact('child')!;

    Widget action(String key, IconData icon, FamilyColor color, String label, String route) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BubblyButton(
        key: Key(key),
        color: color,
        borderRadius: BorderRadius.circular(40),
        padding: const EdgeInsets.all(12),
        onPressed: () => context.push(route),
        child: Row(
          children: [
            CircleAvatar(
              radius: 29,
              backgroundColor: Colors.white,
              child: Icon(icon, size: 30, color: AppColors.ink),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label, style: const TextStyle(fontSize: 24)),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.adultBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                FamilyAvatar(ring: (me?.color ?? FamilyColor.purple).main, size: 56),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Signed in as', style: TextStyle(color: AppColors.muted)),
                    Text(me?.name ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  FamilyAvatar(ring: kid.color.main, size: 150, unread: store.state.unread.contains('child')),
                  Text(kid.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const Text('Child account · protected', style: TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            action('fam-message', Icons.chat_bubble_rounded, FamilyColor.blue, 'Messages', '/chat/child'),
            action('fam-call', Icons.videocam_rounded, FamilyColor.green, 'Video call', '/call/child'),
            action('fam-play', Icons.casino_rounded, FamilyColor.yellow, 'Play a game', '/games/child'),
            const Text(
              'You can only reach people the parent approved. Nobody can find this family by searching.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            TextButton(
              onPressed: () {
                store.switchRole(Role.child);
                context.go('/home');
              },
              child: const Text('Demo: switch this device to the child view'),
            ),
          ],
        ),
      ),
    );
  }
}
