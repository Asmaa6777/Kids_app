import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../theme/colors.dart';
import '../../widgets/bubbly_button.dart';

/// A drawing is a list of strokes; a stroke is a colour + the points the finger passed.
///
/// Why store strokes instead of a PNG?
///   * Tiny: a doodle is a few KB of JSON instead of hundreds of KB of pixels.
///   * Scales to any screen: points are stored from 0.0 to 1.0, not in pixels.
///   * Ready for "draw together": each new stroke can be sent live to the other person.
class Stroke {
  Stroke(this.color, [List<Offset>? points]) : points = points ?? [];

  final Color color;
  final List<Offset> points; // normalised: (0,0) top-left … (1,1) bottom-right

  Map<String, Object?> toJson() => {
    'c': color.toARGB32(),
    'p': [
      for (final p in points) ...[double.parse(p.dx.toStringAsFixed(3)), double.parse(p.dy.toStringAsFixed(3))],
    ],
  };

  factory Stroke.fromJson(Map<String, Object?> j) {
    final flat = (j['p'] as List).cast<num>();
    return Stroke(Color(j['c'] as int), [
      for (var i = 0; i + 1 < flat.length; i += 2) Offset(flat[i].toDouble(), flat[i + 1].toDouble()),
    ]);
  }

  static String encode(List<Stroke> strokes) => jsonEncode([for (final s in strokes) s.toJson()]);

  static List<Stroke> decode(String? data) {
    if (data == null || data.isEmpty) return const [];
    try {
      return [for (final j in jsonDecode(data) as List) Stroke.fromJson((j as Map).cast())];
    } on Object {
      return const [];
    }
  }
}

/// Paints strokes scaled to whatever size the widget is.
class StrokesPainter extends CustomPainter {
  StrokesPainter(this.strokes, {this.width = 8});

  final List<Stroke> strokes;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = width * size.width / 300
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final pts = [for (final p in s.points) Offset(p.dx * size.width, p.dy * size.height)];
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
      } else if (pts.length > 1) {
        canvas.drawPath(Path()..addPolygon(pts, false), paint);
      }
    }
  }

  // Strokes are mutated in place while drawing, so always repaint.
  @override
  bool shouldRepaint(covariant StrokesPainter old) => true;
}

/// Full-screen drawing sheet: colour swatches, undo, clear, and a big star to send.
class DrawingPad extends StatefulWidget {
  const DrawingPad({super.key, required this.onSend});

  final ValueChanged<List<Stroke>> onSend;

  static const inks = [
    Color(0xFF2A2350),
    Color(0xFFFF6B4A),
    Color(0xFFFFAD1F),
    Color(0xFF34A87A),
    Color(0xFF3F8FE0),
    Color(0xFF8C6FE6),
  ];

  @override
  State<DrawingPad> createState() => _DrawingPadState();
}

class _DrawingPadState extends State<DrawingPad> {
  final _strokes = <Stroke>[];
  Color _ink = DrawingPad.inks.first;

  Offset _norm(Offset local, Size size) =>
      Offset((local.dx / size.width).clamp(0, 1), (local.dy / size.height).clamp(0, 1));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FamilyColor.pink.light,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  BubblyButton.circle(
                    key: const Key('draw-close'),
                    semanticLabel: 'Close',
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded, size: 34),
                  ),
                  const Spacer(),
                  BubblyButton.circle(
                    key: const Key('draw-undo'),
                    semanticLabel: 'Undo',
                    onPressed: _strokes.isEmpty ? null : () => setState(_strokes.removeLast),
                    child: const Icon(Icons.undo_rounded, size: 34),
                  ),
                  const SizedBox(width: 12),
                  BubblyButton.circle(
                    key: const Key('draw-clear'),
                    semanticLabel: 'Clear',
                    onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
                    child: const Icon(Icons.delete_rounded, size: 34),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: ColoredBox(
                    color: Colors.white,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size = box.biggest;
                        return GestureDetector(
                          key: const Key('draw-canvas'),
                          onPanStart: (d) => setState(() => _strokes.add(Stroke(_ink, [_norm(d.localPosition, size)]))),
                          onPanUpdate: (d) => setState(() => _strokes.last.points.add(_norm(d.localPosition, size))),
                          child: CustomPaint(painter: StrokesPainter(_strokes), size: size),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final (i, c) in DrawingPad.inks.indexed)
                    GestureDetector(
                      key: Key('ink-$i'),
                      onTap: () => setState(() => _ink = c),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: c == _ink ? AppColors.ink : Colors.white, width: 5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              BubblyButton(
                key: const Key('draw-send'),
                color: FamilyColor.yellow,
                semanticLabel: 'Send drawing',
                onPressed: _strokes.isEmpty
                    ? null
                    : () {
                        widget.onSend(List.of(_strokes));
                        Navigator.pop(context);
                      },
                child: const Center(child: Icon(Icons.star_rounded, size: 40)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
