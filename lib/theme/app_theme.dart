import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const navy = Color(0xFF1C3A28);
  static const navyLight = Color(0xFF274F37);
  static const accent = Color(0xFFC4622A);
  static const background = Color(0xFFF8F5EE);
  static const cream = Color(0xFFF8F5EE);
  static const creamDark = Color(0xFFEFEADF);
  static const surface = Colors.white;
  static const textBody = Color(0xFF2C3E2D);
  static const textMuted = Color(0xFF7A8C7B);
  static const border = Color(0xFFCDD9C6);
  static const sand = Color(0xFFD4B896);

  // Real-time
  static const online = Color(0xFF22C55E);
  static const offline = Color(0xFF9CA3AF);
  static const connecting = Color(0xFFF59E0B);

  // ── Shadow helpers ──────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: navy.withValues(alpha: 0.1),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: navy.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get cardShadowLight => [
        BoxShadow(
          color: navy.withValues(alpha: 0.1),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open': return const Color(0xFF16A34A);
      case 'closed': return const Color(0xFF6B7280);
      case 'in-progress': return const Color(0xFF2563EB);
      case 'completed': return const Color(0xFF7C3AED);
      case 'pending': return const Color(0xFFD97706);
      case 'accepted': return const Color(0xFF16A34A);
      case 'rejected': return const Color(0xFFDC2626);
      case 'withdrawn': return const Color(0xFF6B7280);
      case 'finished': return const Color(0xFF7C3AED);
      default: return const Color(0xFF6B7280);
    }
  }

  static Color statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'open': return const Color(0xFFDCFCE7);
      case 'closed': return const Color(0xFFF3F4F6);
      case 'in-progress': return const Color(0xFFDBEAFE);
      case 'completed': return const Color(0xFFEDE9FE);
      case 'pending': return const Color(0xFFFEF3C7);
      case 'accepted': return const Color(0xFFDCFCE7);
      case 'rejected': return const Color(0xFFFEE2E2);
      case 'withdrawn': return const Color(0xFFF3F4F6);
      case 'finished': return const Color(0xFFEDE9FE);
      default: return const Color(0xFFF3F4F6);
    }
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.navy,
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textBody,
        outline: AppColors.border,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.dmSans(color: AppColors.navy, fontWeight: FontWeight.w900, fontSize: 32),
        displayMedium: GoogleFonts.dmSans(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 28),
        headlineLarge: GoogleFonts.dmSans(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 24),
        headlineMedium: GoogleFonts.dmSans(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 20),
        titleLarge: GoogleFonts.dmSans(color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: GoogleFonts.dmSans(color: AppColors.textBody, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.inter(color: AppColors.textBody, fontSize: 15),
        bodyMedium: GoogleFonts.inter(color: AppColors.textBody, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
        labelSmall: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.border.withValues(alpha: 0.1),
        titleTextStyle: GoogleFonts.dmSans(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 19),
        iconTheme: const IconThemeData(color: AppColors.navy, size: 22),
        actionsIconTheme: const IconThemeData(color: AppColors.navy, size: 22),
        toolbarHeight: 56,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red)),
        labelStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.1), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border.withValues(alpha: 0.1), space: 0, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cream,
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.1)),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textBody),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.navy,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      ),
    );
  }
}
