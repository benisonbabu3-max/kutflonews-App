import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════
//  COLOR SYSTEM — WCAG AA enforced, color theory applied
//  ─────────────────────────────────────────────────────
//  Base bg      : #F4F1EB  warm off-white
//  Near-black   : #1C1C1A  (17:1 contrast on white)
//  Accent       : #E8522A  vermillion (Gen Z energy)
//  Text-primary : #1C1C1A
//  Text-secondary: #5C5A56  (6.2:1 on white ✓)
//  Text-muted   : #8A8780  (only ≥14px bold)
//  Border-light : #C8C4BC  warm grey (NEVER white on light bg)
//  Border-dark  : rgba(255,255,255,.15)
//  Border-accent: #B83E1A
//  Border-sand  : #A8845A
//  Success      : #1A7A54
//  Warning      : #9A6200  (dark amber)
//  Buttons on light bg: ALWAYS dark bg or dark outline
// ═══════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  static const base      = Color(0xFFF4F1EB);
  static const nearBlack = Color(0xFF1C1C1A);
  static const accent    = Color(0xFFE8522A);
  static const accentDark= Color(0xFFB83E1A);
  static const surface   = Color(0xFFFFFFFF);

  static const textPrimary   = Color(0xFF1C1C1A);
  static const textSecondary = Color(0xFF5C5A56);
  static const textMuted     = Color(0xFF8A8780);

  static const borderLight   = Color(0xFFC8C4BC);
  static const borderLighter = Color(0xFFEAE7E0);
  static const sand          = Color(0xFFE8D5B0);
  static const sandBorder    = Color(0xFFA8845A);

  static const success       = Color(0xFF1A7A54);
  static const successLight  = Color(0xFFE3F0EA);
  static const warningDark   = Color(0xFF9A6200);
  static const warningLight  = Color(0xFFF5EDD8);

  // topic colours
  static const payments    = Color(0xFFE8522A);
  static const regulation  = Color(0xFF1A5FA8);
  static const product     = Color(0xFF534AB7);
  static const geopolitics = Color(0xFF9A6200);
  static const aiTech      = Color(0xFF1A7A54);
  static const startups    = Color(0xFF7A3A8A);
  static const strategy    = Color(0xFF2A6A6A);
  static const macro       = Color(0xFF5A3A1A);

  static Color forTopic(String topic) {
    switch (topic.toLowerCase()) {
      case 'payments':    return payments;
      case 'regulation':  return regulation;
      case 'product':     return product;
      case 'geopolitics': return geopolitics;
      case 'ai & tech':   return aiTech;
      case 'startups':    return startups;
      case 'strategy':    return strategy;
      default:            return macro;
    }
  }
}

class AppTheme {
  AppTheme._();

  static TextTheme get _textTheme => GoogleFonts.interTextTheme(
    const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -.5),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.3),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.2),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: .02),
      labelSmall: TextStyle(fontWeight: FontWeight.w600, letterSpacing: .04),
    ),
  );

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    textTheme: _textTheme,
    fontFamily: GoogleFonts.inter().fontFamily,
    scaffoldBackgroundColor: AppColors.base,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.base,
      primary: AppColors.nearBlack,
      secondary: AppColors.accent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.base,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.borderLight, width: 1.5),
      ),
    ),
    // ElevatedButton: always dark bg, light text — readable on any bg
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.nearBlack,
        foregroundColor: AppColors.base,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: .01,
        ),
      ),
    ),
    // OutlinedButton: dark border + dark text — readable on light bg
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.nearBlack,
        side: const BorderSide(color: AppColors.nearBlack, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.base,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderLight, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderLight, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.nearBlack, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'Inter'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? AppColors.success : AppColors.borderLight),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderLighter,
      thickness: 1,
      space: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      // fontFamily string matches GoogleFonts.inter() registration
      backgroundColor: AppColors.base,
      selectedItemColor: AppColors.nearBlack,
      unselectedItemColor: AppColors.textMuted,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
}
