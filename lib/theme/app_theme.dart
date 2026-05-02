import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Core palette (Stitch: clean white + dark slate + red accent) ─────
  static const navy = Color(0xFF0F172A);
  static const navyLight = Color(0xFF1E293B);
  static const accent = Color(0xFFE53935);
  static const background = Color(0xFFFFFFFF);
  static const cream = Color(0xFFF8F9FA);
  static const creamDark = Color(0xFFF0F0F0);
  static const surface = Colors.white;
  static const textBody = Color(0xFF0F172A);
  static const textMuted = Color(0xFF757575);
  static const border = Color(0xFFE0E0E0);
  static const sand = Color(0xFFBDBDBD);

  // Shared screen-level tokens (previously duplicated across screens)
  static const ink = Color(0xFF0F172A);
  static const parchment = Color(0xFFFFFFFF);
  static const rust = Color(0xFFE53935);
  static const muted = Color(0xFF757575);
  static const rule = Color(0xFFE0E0E0);

  // Real-time
  static const online = Color(0xFF22C55E);
  static const offline = Color(0xFF9CA3AF);
  static const connecting = Color(0xFFF59E0B);

  // ── Semantic status palette ──────────────────────────────────────────────
  static const success      = Color(0xFF16A34A);
  static const successLight = Color(0xFFDCFCE7);
  static const successBorder= Color(0xFF86EFAC);
  static const successDark  = Color(0xFF166534);
  static const successMid   = Color(0xFF15803D);

  static const danger       = Color(0xFFDC2626);
  static const dangerLight  = Color(0xFFFEE2E2);
  static const dangerBorder = Color(0xFFFCA5A5);
  static const dangerDark   = Color(0xFFB91C1C);

  static const warning      = Color(0xFFD97706);
  static const warningLight = Color(0xFFFEF3C7);
  static const warningAmber = Color(0xFF92400E);

  static const star         = Color(0xFFF59E0B);
  static const info         = Color(0xFF2563EB);
  static const purple       = Color(0xFF7C3AED);

  // ── Category colors ────────────────────────────────────────────────────
  static Color categoryColor(String cat) {
    switch (cat) {
      case 'Web Development': return const Color(0xFF0F172A);
      case 'Graphic Design':  return const Color(0xFF6B21A8);
      case 'Cybersecurity':   return const Color(0xFF0D47A1);
      case 'Marketing':       return const Color(0xFFE53935);
      case 'Data Science':    return const Color(0xFF1565C0);
      default:                return navy;
    }
  }

  // ── Status accent (left-border cards) ──────────────────────────────────
  static Color statusAccent(String s) {
    switch (s.toLowerCase()) {
      case 'accepted':  return success;
      case 'pending':   return warning;
      case 'rejected':  return danger;
      case 'withdrawn': return muted;
      case 'completed':
      case 'finished':  return purple;
      default:          return rule;
    }
  }

  // ── Admin: report reason colors ────────────────────────────────────────
  static const orange     = Color(0xFFEA580C);
  static const maroon     = Color(0xFF991B1B);
  static const jobBadgeBg = Color(0xFFEFF6FF);
  static const jobBadgeFg = Color(0xFF1D4ED8);
  static const userBadgeBg= Color(0xFFFAF5FF);
  static const userBadgeFg= Color(0xFF7E22CE);

  static Color reportReasonColor(String reason) {
    switch (reason.toLowerCase()) {
      case 'harassment':    return danger;
      case 'spam':          return warning;
      case 'inappropriate': return orange;
      case 'fraud':         return maroon;
      case 'other':         return textMuted;
      default:              return navy;
    }
  }

  // ── Chat ───────────────────────────────────────────────────────────────
  static const chatBubbleOther = Color(0xFFF4F4F6);

  /// Base origin for loading uploaded files (avatars, chat attachments, etc.).
  /// Strips the `/api` suffix from the REST base URL.
  static String get staticOrigin {
    final base = _trimTrailingSlashes(
        const String.fromEnvironment('VITE_API_URL',
            defaultValue: ''));
    if (base.isNotEmpty && base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    final rest = _ApiBaseHelper.apiBaseUrl;
    if (rest.endsWith('/api')) return rest.substring(0, rest.length - 4);
    return rest;
  }

  static String _trimTrailingSlashes(String s) {
    var out = s.trim();
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  // ── Shadow helpers ──────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get cardShadowLight => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 1),
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

class _ApiBaseHelper {
  static String get apiBaseUrl {
    const vite = String.fromEnvironment('VITE_API_URL');
    if (vite.isNotEmpty) return vite;
    const api = String.fromEnvironment('API_BASE_URL');
    if (api.isNotEmpty) return api;
    const host = String.fromEnvironment('API_HOST', defaultValue: 'heartconnect.onrender.com');
    if (host == 'heartconnect.onrender.com') return 'https://heartconnect.onrender.com/api';
    return 'http://$host/api';
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
        displayLarge: GoogleFonts.inter(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 32),
        displayMedium: GoogleFonts.inter(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 28),
        headlineLarge: GoogleFonts.inter(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 24),
        headlineMedium: GoogleFonts.inter(color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge: GoogleFonts.inter(color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: GoogleFonts.inter(color: AppColors.textBody, fontWeight: FontWeight.w600, fontSize: 16),
        bodyLarge: GoogleFonts.inter(color: AppColors.textBody, fontSize: 15),
        bodyMedium: GoogleFonts.inter(color: AppColors.textBody, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
        labelSmall: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.border.withValues(alpha: 0.3),
        titleTextStyle: GoogleFonts.inter(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 18),
        iconTheme: const IconThemeData(color: AppColors.navy, size: 22),
        actionsIconTheme: const IconThemeData(color: AppColors.navy, size: 22),
        toolbarHeight: 56,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
        labelStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(double.infinity, 50),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(double.infinity, 50),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border.withValues(alpha: 0.5), space: 0, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.navy,
        side: BorderSide.none,
        labelStyle: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: AppColors.navy,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      ),
    );
  }
}
