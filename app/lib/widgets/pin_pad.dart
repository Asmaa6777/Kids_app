import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/colors.dart';
import 'bubbly_button.dart';

/// 4-digit PIN entry: four dots and a 3×4 keypad (prototype: `pinPad`).
///
/// When the 4th digit is typed, [onComplete] gets the PIN. It returns `true`
/// if the PIN was accepted; on `false`, the dots shake and reset.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onComplete});

  final bool Function(String pin) onComplete;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _value = '';
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _press(String key) {
    setState(() {
      if (key == 'del') {
        if (_value.isNotEmpty) _value = _value.substring(0, _value.length - 1);
      } else if (_value.length < 4) {
        _value += key;
      }
    });
    if (_value.length == 4) {
      final ok = widget.onComplete(_value);
      if (!ok) {
        setState(() => _value = '');
        _shake.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shake,
          // A sine wave gives a quick left-right wobble.
          builder: (_, child) => Transform.translate(offset: Offset(10 * _wobble(_shake.value), 0), child: child),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  key: Key('pin-dot-$i'),
                  margin: const EdgeInsets.all(8),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _value.length ? AppColors.ink : Colors.transparent,
                    border: Border.all(color: AppColors.ink, width: 3),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 3 * 78 + 2 * 14,
          child: Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final k in keys)
                k.isEmpty
                    ? const SizedBox(width: 78, height: 78)
                    : BubblyButton.circle(
                        key: Key('pin-$k'),
                        size: 78,
                        semanticLabel: k == 'del' ? 'Delete' : k,
                        onPressed: () => _press(k),
                        child: k == 'del'
                            ? const Icon(Icons.backspace_rounded, size: 30)
                            : Text(k, style: const TextStyle(fontSize: 30)),
                      ),
            ],
          ),
        ),
      ],
    );
  }

  /// Two full left-right swings over the animation (0 → 1).
  static double _wobble(double t) => math.sin(t * 4 * math.pi);
}
