import 'package:material_ui/material_ui.dart';

import '../theme/colors.dart';

/// The prototype's signature "3D" button (CSS class `.b3d`).
///
/// How it works:
///   * A darker shadow sits [depth] pixels *below* the button, so it looks thick.
///   * While a finger is down, the surface slides down by [depth] - 2 pixels and
///     the shadow shrinks, so the button looks pressed in.
///
/// Every tappable thing in the child UI is built from this one widget.
class BubblyButton extends StatefulWidget {
  const BubblyButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color = FamilyColor.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(40)),
    this.padding = const EdgeInsets.all(16),
    this.depth = 8,
    this.semanticLabel,
  }) : size = null;

  /// A circular button, like the prototype's `.cbtn` (back, mic, hang up…).
  const BubblyButton.circle({
    super.key,
    required this.onPressed,
    required this.child,
    this.color = FamilyColor.white,
    double this.size = 72,
    this.semanticLabel,
  }) : borderRadius = const BorderRadius.all(Radius.circular(999)),
       padding = EdgeInsets.zero,
       depth = 8;

  final VoidCallback? onPressed;
  final Widget child;
  final FamilyColor color;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final double depth;
  final String? semanticLabel;

  /// Fixed width/height (circle buttons only).
  final double? size;

  @override
  State<BubblyButton> createState() => _BubblyButtonState();
}

class _BubblyButtonState extends State<BubblyButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  void _setDown(bool value) {
    if (_enabled && _down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final press = _down ? widget.depth - 2 : 0.0;

    Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      transform: Matrix4.translationValues(0, press, 0),
      width: widget.size,
      height: widget.size,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color.main,
        borderRadius: widget.borderRadius,
        boxShadow: [BoxShadow(color: widget.color.dark, offset: Offset(0, widget.depth - press))],
      ),
      alignment: widget.size != null ? Alignment.center : null,
      child: IconTheme.merge(
        data: const IconThemeData(color: AppColors.ink),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
          child: widget.child,
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: Opacity(
        opacity: _enabled ? 1 : 0.4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setDown(true),
          onTapUp: (_) => _setDown(false),
          onTapCancel: () => _setDown(false),
          onTap: widget.onPressed,
          // Leave room underneath so the shadow is never clipped.
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.depth),
            child: surface,
          ),
        ),
      ),
    );
  }
}
