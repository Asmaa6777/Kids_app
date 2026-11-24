import 'package:material_ui/material_ui.dart';

import 'colors.dart';

/// One place for the app's look, so screens don't hard-code fonts or colours.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Baloo2',
    colorScheme: ColorScheme.fromSeed(
      seedColor: FamilyColor.coral.main,
      surface: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
          // Big, bold, rounded text: the child is a pre-reader, so words are
          // decoration and the voice (TTS) carries the meaning.
          displaySmall: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, height: 1),
          headlineMedium: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.1),
          titleLarge: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.05),
          bodyLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          bodyMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
  );
}
