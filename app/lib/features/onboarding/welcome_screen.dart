import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/colors.dart';
import '../../widgets/bubbly_button.dart';

/// First screen: "Set up for my child" (parent) or "Join my family" (relative).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.home_rounded, size: 104, color: AppColors.ink),
            Text('Family Call', textAlign: TextAlign.center, style: text.displaySmall),
            const SizedBox(height: 8),
            Text(
              'A safe place to talk and play — only with family.',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            _ChoiceCard(
              key: const Key('choose-parent'),
              icon: Icons.lock_rounded,
              color: FamilyColor.coral,
              title: 'Set up for my child',
              subtitle: "I'm the parent. I choose who she can talk to.",
              onPressed: () => context.go('/setup'),
            ),
            const SizedBox(height: 16),
            _ChoiceCard(
              key: const Key('choose-family'),
              icon: Icons.mail_rounded,
              color: FamilyColor.blue,
              title: 'Join my family',
              subtitle: 'I got an invite code from the parent.',
              onPressed: () => context.go('/join'),
            ),
            const SizedBox(height: 20),
            Text(
              'No ads · No strangers · Invite only',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final FamilyColor color;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BubblyButton(
      onPressed: onPressed,
      borderRadius: BorderRadius.circular(36),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(radius: 36, backgroundColor: color.main, child: Icon(icon, size: 36, color: AppColors.ink)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, height: 1.1)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(fontSize: 15, color: AppColors.muted, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
