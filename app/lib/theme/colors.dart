import 'package:material_ui/material_ui.dart';

/// Brand colours, copied from the prototype's CSS variables (`--bg`, `--ink`, …).
abstract final class AppColors {
  static const background = Color(0xFFFFF5E4);
  static const ink = Color(0xFF2A2350);
  static const silhouette = Color(0xFF554D6E);
  static const cream = Color(0xFFFFF4E3);
  static const muted = Color(0xFF7D7596);
  static const unreadDot = Color(0xFF4A35E0);
  static const night = Color(0xFF1F1A45);
  static const night2 = Color(0xFF332C66);
  static const adultBackground = Color(0xFFF6F3FB);
  static const shade = Color(0x242A2350); // rgba(42,35,80,.14)
}

/// Each family member gets one colour. Every colour has three shades:
/// [main] for the surface, [dark] for the 3D "shadow" edge, [light] for tints.
enum FamilyColor {
  coral(Color(0xFFFF8A70), Color(0xFFE06A52), Color(0xFFFFE3DD)),
  yellow(Color(0xFFFFC947), Color(0xFFD4A21F), Color(0xFFFFF1CC)),
  green(Color(0xFF5DD1A4), Color(0xFF38A97C), Color(0xFFDCF5EA)),
  blue(Color(0xFF6EB6FF), Color(0xFF4592E0), Color(0xFFDFEEFC)),
  purple(Color(0xFFB79CFF), Color(0xFF8F72E8), Color(0xFFECE4FF)),
  pink(Color(0xFFFF9CC8), Color(0xFFE076A8), Color(0xFFFFE0EC)),
  red(Color(0xFFFF5A5F), Color(0xFFCF3D43), Color(0xFFFFE0E1)),
  white(Color(0xFFFFFFFF), AppColors.shade, Color(0xFFFFFFFF));

  const FamilyColor(this.main, this.dark, this.light);

  final Color main;
  final Color dark;
  final Color light;

  /// Colours a parent may assign to a contact (red and white are for UI only).
  static const choosable = [coral, yellow, green, blue, purple, pink];

  static FamilyColor byName(String name) => values.firstWhere((c) => c.name == name, orElse: () => coral);
}
