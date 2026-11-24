import 'package:material_ui/material_ui.dart';

import '../../theme/colors.dart';

/// An invisible 84×84 square in the top-left corner.
///
/// Hold it for [holdFor] (3 s) and [onOpened] fires. After the first second a
/// faint ring appears and fills up, so the parent knows it's working. A child
/// tapping around won't trigger it by accident.
class ParentGateCorner extends StatefulWidget {
  const ParentGateCorner({super.key, required this.onOpened, this.holdFor = const Duration(seconds: 3)});

  final VoidCallback onOpened;
  final Duration holdFor;

  @override
  State<ParentGateCorner> createState() => _ParentGateCornerState();
}

class _ParentGateCornerState extends State<ParentGateCorner> with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(vsync: this, duration: widget.holdFor)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _hold.value = 0;
        widget.onOpened();
      }
    });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: Listener(
        key: const Key('parent-gate'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _hold.forward(from: 0),
        onPointerUp: (_) => _hold.reset(),
        onPointerCancel: (_) => _hold.reset(),
        child: SizedBox.square(
          dimension: 84,
          child: AnimatedBuilder(
            animation: _hold,
            builder: (_, _) {
              final p = _hold.value;
              if (p < 0.33) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  value: (p - 0.33) / 0.67,
                  strokeWidth: 5,
                  color: AppColors.ink.withValues(alpha: 0.6),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
