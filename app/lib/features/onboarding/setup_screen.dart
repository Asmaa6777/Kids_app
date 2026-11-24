import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../data/family_store.dart';
import '../../services/kiosk.dart';
import '../../theme/colors.dart';
import '../../widgets/bubbly_button.dart';
import '../../widgets/pin_pad.dart';

/// Parent setup wizard: child's name → choose PIN → repeat PIN → safety checklist.
///
/// One StatefulWidget with a `_step` counter is simpler than four routes,
/// and the half-typed answers stay in memory while the parent moves back and forth.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _step = 1;
  final _name = TextEditingController();
  String _firstPin = '';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _back() => _step == 1 ? context.go('/') : setState(() => _step--);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = Row(
      children: [
        if (_step < 4)
          BubblyButton.circle(
            key: const Key('back'),
            semanticLabel: 'Back',
            onPressed: _back,
            child: const Icon(Icons.arrow_back_rounded, size: 34),
          ),
        const SizedBox(width: 14),
        if (_step < 4)
          Text('STEP $_step OF 3', style: TextStyle(color: FamilyColor.coral.dark, letterSpacing: 1, fontSize: 13)),
      ],
    );

    final Widget body = switch (_step) {
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("What's your child's name?", style: text.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'It shows on her screens. Family will see it too.',
            style: text.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('child-name'),
            controller: _name,
            maxLength: 20,
            autofocus: true,
            style: const TextStyle(fontSize: 22),
            decoration: InputDecoration(
              hintText: 'e.g. Mia',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          const SizedBox(height: 12),
          BubblyButton(
            key: const Key('next'),
            color: FamilyColor.coral,
            onPressed: () {
              if (_name.text.trim().isEmpty) return _toast('Please type a name');
              setState(() => _step = 2);
            },
            child: const Center(child: Text('Next', style: TextStyle(fontSize: 24))),
          ),
        ],
      ),
      2 || 3 => Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: (_step == 2 ? FamilyColor.coral : FamilyColor.yellow).main,
            child: Icon(_step == 2 ? Icons.lock_rounded : Icons.key_rounded, size: 48, color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          Text(_step == 2 ? 'Choose a parent PIN' : 'Type it again', style: text.headlineMedium),
          const SizedBox(height: 6),
          Text(
            _step == 2 ? '4 numbers. Only you know it — it unlocks the parent area.' : 'Just to be sure.',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          PinPad(
            key: ValueKey('pinpad-$_step'), // new pad (empty dots) for each step
            onComplete: (pin) {
              if (_step == 2) {
                _firstPin = pin;
                setState(() => _step = 3);
                return true;
              }
              if (pin != _firstPin) {
                _toast("PINs don't match — try again");
                return false;
              }
              context.read<FamilyStore>().completeParentSetup(childName: _name.text.trim(), pin: pin);
              setState(() => _step = 4);
              return true;
            },
          ),
        ],
      ),
      _ => _Checklist(childName: _name.text.trim()),
    };

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(22), children: [top, const SizedBox(height: 18), body]),
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist({required this.childName});
  final String childName;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, FamilyColor c, String title, String sub) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: AppColors.shade, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: c.main,
            child: Icon(icon, color: AppColors.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(sub, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Almost done!', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        item(
          Icons.push_pin_rounded,
          FamilyColor.blue,
          'The app pins itself',
          'Tap "Start" and accept "Pin this app?". Home and Recents are blocked until you unlock it.',
        ),
        item(
          Icons.block_rounded,
          FamilyColor.coral,
          'Remove WhatsApp & Messenger',
          'From this device. The strongest protection of all.',
        ),
        item(
          Icons.family_restroom_rounded,
          FamilyColor.green,
          'Optional: Google Family Link',
          'Adds screen-time limits and app approval on top of this app.',
        ),
        item(
          Icons.lock_rounded,
          FamilyColor.purple,
          'Your secret door',
          'Hold the top-left corner for 3 seconds, then type your PIN.',
        ),
        const SizedBox(height: 6),
        BubblyButton(
          key: const Key('start'),
          color: FamilyColor.green,
          onPressed: () {
            context.read<Kiosk>().lock();
            context.go('/home');
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_rounded, size: 30),
              const SizedBox(width: 8),
              Flexible(child: Text("Start $childName's app", style: const TextStyle(fontSize: 22))),
            ],
          ),
        ),
      ],
    );
  }
}
