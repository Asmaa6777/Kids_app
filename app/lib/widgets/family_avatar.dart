import 'package:material_ui/material_ui.dart';

import '../theme/colors.dart';

/// A cream circle with a person silhouette and a coloured ring
/// (prototype: `.aw` / `.ava`). Later this will show a real photo.
class FamilyAvatar extends StatelessWidget {
  const FamilyAvatar({
    super.key,
    required this.ring,
    this.size = 64,
    this.unread = false,
  });

  final Color ring;
  final double size;

  /// Shows the blue "new message" dot in the top-right corner.
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final border = (size * 0.06).clamp(4.0, 10.0);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cream,
              border: Border.all(color: ring, width: border),
            ),
            child: ClipOval(child: CustomPaint(painter: _SilhouettePainter(), size: Size.square(size))),
          ),
          if (unread)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                key: const Key('unread-dot'),
                width: size * 0.24,
                height: size * 0.24,
                decoration: BoxDecoration(
                  color: AppColors.unreadDot,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Draws the same head + shoulders shape as the prototype's SVG.
class _SilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100; // the SVG used a 100×100 viewBox
    final paint = Paint()..color = AppColors.silhouette;
    canvas.drawCircle(Offset(50 * s, 40 * s), 17 * s, paint);
    final body = Path()
      ..moveTo(18 * s, 102 * s)
      ..cubicTo(20 * s, 75 * s, 34 * s, 63 * s, 50 * s, 63 * s)
      ..cubicTo(66 * s, 63 * s, 80 * s, 75 * s, 82 * s, 102 * s)
      ..close();
    canvas.drawPath(body, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
