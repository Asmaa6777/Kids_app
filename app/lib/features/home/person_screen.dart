import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../services/speaker.dart';
import '../../theme/colors.dart';
import '../../widgets/back_button.dart';
import '../../widgets/bubbly_button.dart';
import '../../widgets/family_avatar.dart';

/// Design page 2: a big avatar and three choices — Call, Message, Play.
class PersonScreen extends StatelessWidget {
  const PersonScreen({super.key, required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FamilyStore>();
    final c = store.contact(contactId);
    if (c == null) return const Scaffold(body: Center(child: Text('Not found')));

    Widget choice(String key, IconData icon, FamilyColor color, String label, String route, String spoken) =>
        BubblyButton(
          key: Key(key),
          color: color,
          borderRadius: BorderRadius.circular(52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          semanticLabel: label,
          onPressed: () {
            context.read<Speaker>().say(spoken);
            context.push(route);
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Icon(icon, size: 42, color: AppColors.ink),
              ),
              const SizedBox(width: 22),
              // Shrinks (never wraps or overflows) on narrow phones.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(label, style: const TextStyle(fontSize: 34)),
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: RoundBackButton(fallback: '/home'),
            ),
            const SizedBox(height: 8),
            Center(
              child: FamilyAvatar(ring: c.color.main, size: 150, unread: store.state.unread.contains(c.id)),
            ),
            const SizedBox(height: 10),
            Text(
              c.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, height: 1),
            ),
            const SizedBox(height: 26),
            choice('call', Icons.videocam_rounded, FamilyColor.green, 'Call', '/call/${c.id}', 'Call ${c.name}'),
            const SizedBox(height: 14),
            choice('message', Icons.chat_bubble_rounded, FamilyColor.blue, 'Message', '/chat/${c.id}', 'Messages'),
            const SizedBox(height: 14),
            choice('play', Icons.casino_rounded, FamilyColor.yellow, 'Play', '/games/${c.id}', "Let's play"),
          ],
        ),
      ),
    );
  }
}
