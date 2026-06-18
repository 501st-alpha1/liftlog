import 'package:flutter/material.dart';

// ── Palette ─────────────────────────────────────────────────────────────────
// Dark background: near-black with a warm tint (not pure #000 — easier on eyes)
// Accent: a punchy amber-orange — reads well under gym fluorescents
// Surface: dark charcoal cards
// Text: high-contrast off-white

const Color kBackground = Color(0xFF111214);
const Color kSurface = Color(0xFF1C1E21);
const Color kSurfaceVariant = Color(0xFF26292E);
const Color kAccent = Color(0xFFE8A020); // amber-orange
const Color kAccentDim = Color(0xFF7A540F);
const Color kOnBackground = Color(0xFFF0EDE8); // warm off-white
const Color kOnSurface = Color(0xFFD8D5D0);
const Color kOnSurfaceDim = Color(0xFF888580);
const Color kSuccess = Color(0xFF4CAF7D);
const Color kDestructive = Color(0xFFE05252);

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: kBackground,
    colorScheme: const ColorScheme.dark(
      primary: kAccent,
      onPrimary: Color(0xFF1A1000),
      secondary: kAccentDim,
      surface: kSurface,
      onSurface: kOnSurface,
      error: kDestructive,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBackground,
      foregroundColor: kOnBackground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: kOnBackground,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: const CardThemeData(
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: kOnSurfaceDim),
      hintStyle: const TextStyle(color: kOnSurfaceDim),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: const Color(0xFF1A1000),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kAccent),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kSurfaceVariant,
      selectedColor: kAccentDim,
      labelStyle: const TextStyle(color: kOnSurface, fontSize: 13),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2C2F33),
      thickness: 1,
      space: 1,
    ),
    textTheme: base.textTheme.copyWith(
      // Large numbers (weight, reps)
      displayLarge: const TextStyle(
        color: kOnBackground,
        fontSize: 48,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
      ),
      // Section headers
      titleLarge: const TextStyle(
        color: kOnBackground,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: const TextStyle(
        color: kOnBackground,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      // Body
      bodyLarge: const TextStyle(color: kOnSurface, fontSize: 15),
      bodyMedium: const TextStyle(color: kOnSurface, fontSize: 14),
      bodySmall: const TextStyle(color: kOnSurfaceDim, fontSize: 12),
      // Labels (set numbers, metadata)
      labelLarge: const TextStyle(
        color: kAccent,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ),
  );
}
