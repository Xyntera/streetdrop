import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg            = Color(0xFF050510);
  static const glass         = Color(0x0DFFFFFF);
  static const glassBorder   = Color(0x1AFFFFFF);
  static const primary       = Color(0xFF6366F1);
  static const primaryDark   = Color(0xFF4338CA);
  static const primaryLight  = Color(0xFF818CF8);
  static const accent        = Color(0xFF00FFA3);
  static const teal          = Color(0xFF14B8A6);
  static const success       = Color(0xFF10B981);
  static const danger        = Color(0xFFFF3B5C);
  static const warning       = Color(0xFFF59E0B);
  static const textPrimary   = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textDim       = Color(0xFF475569);
  static const textHint      = Color(0xFF2D3748);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary, secondary: AppColors.accent,
      surface: Color(0xFF0E0E26), background: AppColors.bg, error: AppColors.danger,
    ),
    textTheme: _text,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, elevation: 0,
      scrolledUnderElevation: 0, systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );

  static TextTheme get _text => TextTheme(
    displayLarge:   GoogleFonts.outfit(fontSize: 56, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -2.5),
    headlineLarge:  GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
    headlineMedium: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    titleLarge:     GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    titleMedium:    GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    bodyLarge:      GoogleFonts.outfit(fontSize: 16, color: AppColors.textSecondary, height: 1.6),
    bodyMedium:     GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
    bodySmall:      GoogleFonts.outfit(fontSize: 12, color: AppColors.textDim,       height: 1.4),
    labelLarge:     GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    labelSmall:     GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textDim, letterSpacing: 0.8),
  );
}
