import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../services/kiosk.dart';
import '../../theme/colors.dart';
import '../../widgets/back_button.dart';
import '../../widgets/pin_pad.dart';

/// "Grown-ups only": the parent PIN unlocks the app (unpins it) and opens the parent area.
class GateScreen extends StatelessWidget {
  const GateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: RoundBackButton(fallback: '/home', icon: Icons.close_rounded),
            ),
            const SizedBox(height: 10),
            CircleAvatar(
              radius: 48,
              backgroundColor: FamilyColor.purple.main,
              child: const Icon(Icons.lock_rounded, size: 48, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            Text('Grown-ups only', textAlign: TextAlign.center, style: text.headlineMedium),
            Text(
              'Type the parent PIN',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Center(
              child: PinPad(
                onComplete: (pin) {
                  if (!context.read<FamilyStore>().checkPin(pin)) return false;
                  context.read<Kiosk>().unlock();
                  context.pushReplacement('/parent');
                  return true;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
