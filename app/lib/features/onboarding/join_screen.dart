import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../theme/colors.dart';
import '../../widgets/back_button.dart';
import '../../widgets/bubbly_button.dart';

/// A relative types the invite code from the parent, their name, and a colour.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  FamilyColor _color = FamilyColor.purple;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _join() {
    final error = context.read<FamilyStore>().joinFamily(code: _code.text, name: _name.text, color: _color);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.go('/family');
  }

  InputDecoration _field(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    counterText: '',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
  );

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
              child: RoundBackButton(fallback: '/'),
            ),
            const SizedBox(height: 14),
            Text('Join the family', style: text.headlineMedium),
            Text('Type the code the parent sent you.', style: text.bodyLarge?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 14),
            TextField(
              key: const Key('code'),
              controller: _code,
              maxLength: 6,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w800),
              decoration: _field('······'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Prototype demo code: ${FamilyStore.demoCode}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('name'),
              controller: _name,
              maxLength: 20,
              style: const TextStyle(fontSize: 22),
              decoration: _field('Your name (e.g. Grandma)'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Pick your colour',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              children: [
                for (final c in FamilyColor.choosable)
                  Semantics(
                    button: true,
                    selected: c == _color,
                    label: c.name,
                    child: GestureDetector(
                      key: Key('color-${c.name}'),
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: c.main,
                          shape: BoxShape.circle,
                          border: Border.all(color: c == _color ? AppColors.ink : Colors.white, width: 5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            BubblyButton(
              key: const Key('join'),
              color: FamilyColor.coral,
              onPressed: _join,
              child: const Center(child: Text('Join', style: TextStyle(fontSize: 24))),
            ),
          ],
        ),
      ),
    );
  }
}
