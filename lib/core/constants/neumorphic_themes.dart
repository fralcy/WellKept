import 'package:flutter/material.dart';

/// A hand-rolled neumorphic palette: a base surface color plus a light and
/// a dark shadow color (soft-UI raised/pressed effects come from pairing
/// those two `BoxShadow`s), and an accent color used both for selection
/// highlights and to seed the app's derived Material `ColorScheme`.
class NeumorphicThemeConfig {
  const NeumorphicThemeConfig({
    required this.id,
    required this.label,
    required this.background,
    required this.lightShadow,
    required this.darkShadow,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  final String id;
  final String label;
  final Color background;
  final Color lightShadow;
  final Color darkShadow;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
}

/// A handful of preset palettes — deliberately not a full custom color
/// builder, matching the "preset theme + simple color picker" requirement.
const List<NeumorphicThemeConfig> neumorphicThemePresets = [
  NeumorphicThemeConfig(
    id: 'sky',
    label: 'Sky',
    background: Color(0xFFE6EBF2),
    lightShadow: Color(0xFFFFFFFF),
    darkShadow: Color(0xFFB6C0CE),
    accent: Color(0xFF5B7FDB),
    textPrimary: Color(0xFF33415C),
    textSecondary: Color(0xFF7A8AA6),
  ),
  NeumorphicThemeConfig(
    id: 'sand',
    label: 'Sand',
    background: Color(0xFFF0E9DF),
    lightShadow: Color(0xFFFFFFFF),
    darkShadow: Color(0xFFCFC3AF),
    accent: Color(0xFFD98B4A),
    textPrimary: Color(0xFF5C4A33),
    textSecondary: Color(0xFF9C8A70),
  ),
  NeumorphicThemeConfig(
    id: 'mint',
    label: 'Mint',
    background: Color(0xFFE3EFEA),
    lightShadow: Color(0xFFFFFFFF),
    darkShadow: Color(0xFFB9CFC4),
    accent: Color(0xFF3FA980),
    textPrimary: Color(0xFF294A3E),
    textSecondary: Color(0xFF7A9C8E),
  ),
  NeumorphicThemeConfig(
    id: 'rose',
    label: 'Rose',
    background: Color(0xFFF3E7EA),
    lightShadow: Color(0xFFFFFFFF),
    darkShadow: Color(0xFFD8BAC1),
    accent: Color(0xFFD1608A),
    textPrimary: Color(0xFF5C3340),
    textSecondary: Color(0xFF9C7683),
  ),
  NeumorphicThemeConfig(
    id: 'slate',
    label: 'Slate',
    background: Color(0xFF2B2F36),
    // Wider gap than the light presets — a subtle shadow pair reads as
    // "flat and hard to see" once translated to a dark surface, so the
    // raised/pressed effect needs more contrast here to stay legible.
    lightShadow: Color(0xFF484F5C),
    darkShadow: Color(0xFF121417),
    accent: Color(0xFF7C9CE0),
    textPrimary: Color(0xFFE7EAF0),
    textSecondary: Color(0xFF9CA5B4),
  ),
];

NeumorphicThemeConfig themeById(String id) => neumorphicThemePresets.firstWhere(
  (t) => t.id == id,
  orElse: () => neumorphicThemePresets.first,
);
