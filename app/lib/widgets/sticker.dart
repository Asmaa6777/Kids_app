import 'package:material_ui/material_ui.dart';

import '../theme/colors.dart';

/// The sticker set. Each sticker is a built-in rounded Material icon on a
/// coloured circle with a white rim, so no image files are needed.
enum Sticker {
  heart(Icons.favorite_rounded, FamilyColor.pink),
  star(Icons.star_rounded, FamilyColor.yellow),
  sun(Icons.wb_sunny_rounded, FamilyColor.yellow),
  flower(Icons.local_florist_rounded, FamilyColor.pink),
  rainbow(Icons.looks_rounded, FamilyColor.purple),
  cloud(Icons.cloud_rounded, FamilyColor.blue),
  party(Icons.celebration_rounded, FamilyColor.coral),
  cat(Icons.pets_rounded, FamilyColor.green);

  const Sticker(this.icon, this.color);
  final IconData icon;
  final FamilyColor color;

  static Sticker byName(String? name) => values.firstWhere((s) => s.name == name, orElse: () => heart);
}

class StickerView extends StatelessWidget {
  const StickerView(this.sticker, {super.key, this.size = 116});

  final Sticker sticker;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: sticker.color.light,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: size * 0.05),
    ),
    child: Icon(sticker.icon, size: size * 0.62, color: sticker.color.dark),
  );
}
