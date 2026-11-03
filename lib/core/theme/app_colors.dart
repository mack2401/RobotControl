import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppColors {
  // Light Palette Tokens
  static const Color lightBackground = Color(0xFFF8FAFC); // slate-50
  static const Color lightSurface = Color(0xFFFFFFFF);    // pure white
  static const Color lightSurfaceDim = Color(0xFFF1F5F9); // slate-100
  static const Color lightSurfaceBright = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF8FAFC);
  static const Color lightSurfaceContainer = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerHigh = Color(0xFFF1F5F9);
  static const Color lightSurfaceContainerHighest = Color(0xFFE2E8F0);
  static const Color lightOnSurface = Color(0xFF0F172A);        // slate-900
  static const Color lightOnSurfaceVariant = Color(0xFF64748B); // slate-500
  static const Color lightOutline = Color(0xFFE2E8F0);          // slate-200
  static const Color lightOutlineVariant = Color(0xFFF1F5F9);   // slate-100
  static const Color lightSubtleText = Color(0xFF94A3B8);       // slate-400
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightCardShadow = Color(0x0D0F172A);

  // Dark Palette Tokens (Obsidian Slate Theme)
  static const Color darkBackground = Color(0xFF0B0F17); // rich deep obsidian canvas
  static const Color darkSurface = Color(0xFF1E293B);    // slate-800 card surface
  static const Color darkSurfaceDim = Color(0xFF0F172A); // slate-900 inner surface
  static const Color darkSurfaceBright = Color(0xFF334155);
  static const Color darkSurfaceContainerLowest = Color(0xFF0B0F17);
  static const Color darkSurfaceContainerLow = Color(0xFF0F172A);
  static const Color darkSurfaceContainer = Color(0xFF1E293B);
  static const Color darkSurfaceContainerHigh = Color(0xFF334155);
  static const Color darkSurfaceContainerHighest = Color(0xFF475569);
  static const Color darkOnSurface = Color(0xFFF8FAFC);        // slate-50 crisp typography
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8); // slate-400
  static const Color darkOutline = Color(0xFF334155);          // slate-700
  static const Color darkOutlineVariant = Color(0xFF1E293B);
  static const Color darkSubtleText = Color(0xFF64748B);       // slate-500
  static const Color darkCardBorder = Color(0xFF334155);
  static const Color darkCardShadow = Color(0x33000000);

  // Legacy default constants (ensures const constructors remain valid)
  static const Color background = lightBackground;
  static const Color surface = lightSurface;
  static const Color surfaceDim = lightSurfaceDim;
  static const Color surfaceBright = lightSurfaceBright;
  static const Color surfaceContainerLowest = lightSurfaceContainerLowest;
  static const Color surfaceContainerLow = lightSurfaceContainerLow;
  static const Color surfaceContainer = lightSurfaceContainer;
  static const Color surfaceContainerHigh = lightSurfaceContainerHigh;
  static const Color surfaceContainerHighest = lightSurfaceContainerHighest;
  static const Color onSurface = lightOnSurface;
  static const Color onSurfaceVariant = lightOnSurfaceVariant;
  static const Color outline = lightOutline;
  static const Color outlineVariant = lightOutlineVariant;
  static const Color subtleText = lightSubtleText;
  static const Color cardBorder = lightCardBorder;
  static const Color cardShadow = lightCardShadow;

  // Stitch Sky Blue Primary
  static const Color primary = Color(0xFF0284C7);       // sky-600
  static const Color primaryLight = Color(0xFF0EA5E9);  // sky-500
  static const Color primaryGradientStart = Color(0xFF0EA5E9);
  static const Color primaryGradientEnd = Color(0xFF0284C7);
  static const Color primaryTint = Color(0xFF38BDF8);   // sky-400
  static const Color primaryContainer = Color(0xFFE0F2FE); // sky-100
  static const Color primaryContainerLow = Color(0xFFF0F9FF); // sky-50
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Signal & Status Accents
  static const Color success = Color(0xFF059669);          // emerald-600
  static const Color successLight = Color(0xFF10B981);     // emerald-500
  static const Color successContainer = Color(0xFFECFDF5); // emerald-50
  static const Color successBorder = Color(0xFFA7F3D0);    // emerald-200

  static const Color danger = Color(0xFFDC2626);           // red-600
  static const Color dangerLight = Color(0xFFEF4444);      // red-500
  static const Color dangerContainer = Color(0xFFFEF2F2);  // red-50
  static const Color dangerBorder = Color(0xFFFECACA);     // red-200

  static const Color warning = Color(0xFFD97706);          // amber-600
  static const Color warningLight = Color(0xFFF59E0B);     // amber-500
  static const Color warningContainer = Color(0xFFFFFBEB); // amber-50
  static const Color warningBorder = Color(0xFFFDE68A);    // amber-200

  static const Color purple = Color(0xFF9333EA);           // purple-600
  static const Color purpleContainer = Color(0xFFFAF5FF);  // purple-50
  static const Color pink = Color(0xFFDB2777);             // pink-600
  static const Color pinkContainer = Color(0xFFFDF2F8);    // pink-50
  static const Color hudCyanBorder = Color(0xFFBAE6FD);

  // Dynamic getters resolving theme mode
  static bool get isDark => AppTheme.isDarkMode;

  static Color get dynamicBackground => isDark ? darkBackground : lightBackground;
  static Color get dynamicSurface => isDark ? darkSurface : lightSurface;
  static Color get dynamicSurfaceDim => isDark ? darkSurfaceDim : lightSurfaceDim;
  static Color get dynamicOnSurface => isDark ? darkOnSurface : lightOnSurface;
  static Color get dynamicOnSurfaceVariant => isDark ? darkOnSurfaceVariant : lightOnSurfaceVariant;
  static Color get dynamicOutline => isDark ? darkOutline : lightOutline;
  static Color get dynamicCardBorder => isDark ? darkCardBorder : lightCardBorder;
}
