import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── MapSumbong Design System ───────────────────────────────────────────────────
// Aesthetic: "Civic Tech Warmth" — clean, trustworthy, accessible, Filipino
// Color story: Deep navy authority + warm amber urgency + fresh teal action

class AppColors {
  // Brand
  static const Color primary = Color(0xFF1B4FD8); // Civic blue
  static const Color primaryDark = Color(0xFF1340B0);
  static const Color primaryLight = Color(0xFF3B6FE8);
  static const Color primarySurface = Color(0xFFEEF2FF);

  // Accent
  static const Color accent = Color(0xFF0EA5E9); // Action teal-blue
  static const Color accentLight = Color(0xFFE0F2FE);

  // Urgency palette
  static const Color critical = Color(0xFFEF4444);
  static const Color criticalLight = Color(0xFFFEF2F2);
  static const Color high = Color(0xFFF97316);
  static const Color highLight = Color(0xFFFFF7ED);
  static const Color medium = Color(0xFFF59E0B);
  static const Color mediumLight = Color(0xFFFFFBEB);
  static const Color low = Color(0xFF22C55E);
  static const Color lowLight = Color(0xFFF0FDF4);

  // Status
  static const Color received = Color(0xFF3B82F6);
  static const Color inProgress = Color(0xFFF59E0B);
  static const Color resolved = Color(0xFF22C55E);
  static const Color reopened = Color(0xFFEF4444);

  // Neutrals
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Chat bubbles
  static const Color userBubble = Color(0xFF1B4FD8);
  static const Color aiBubble = Color(0xFFF1F5F9);
  static const Color systemBubble = Color(0xFFFFFBEB);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double full = 999;
}

class AppShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> button = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.3),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> fab = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.35),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.surface,
        background: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Nunito',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.critical, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontFamily: 'Nunito',
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        dividerColor: AppColors.border,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14,
          color: Colors.white,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -1),
        displayMedium: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5),
        headlineLarge: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3),
        headlineMedium: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineSmall: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleLarge: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.2),
        titleMedium: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleSmall: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        bodyLarge: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        bodyMedium: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        bodySmall: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w400, color: AppColors.textMuted),
        labelLarge: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, letterSpacing: 0.3),
        labelMedium: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, letterSpacing: 0.2),
        labelSmall: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    );
  }
}

// ── Urgency helpers ───────────────────────────────────────────────────────────

extension UrgencyExtension on String {
  Color get urgencyColor {
    switch (this) {
      case 'critical': return AppColors.critical;
      case 'high':     return AppColors.high;
      case 'medium':   return AppColors.medium;
      case 'low':      return AppColors.low;
      default:         return AppColors.textMuted;
    }
  }

  Color get urgencyBg {
    switch (this) {
      case 'critical': return AppColors.criticalLight;
      case 'high':     return AppColors.highLight;
      case 'medium':   return AppColors.mediumLight;
      case 'low':      return AppColors.lowLight;
      default:         return AppColors.surfaceVariant;
    }
  }

  String get urgencyLabel {
    switch (this) {
      case 'critical': return 'Kritikal';
      case 'high':     return 'Mataas';
      case 'medium':   return 'Katamtaman';
      case 'low':      return 'Mababa';
      default:         return this;
    }
  }

  Color get statusColor {
    switch (this) {
      case 'received':         return AppColors.received;
      case 'in_progress':      return AppColors.inProgress;
      case 'repair_scheduled': return const Color(0xFF8B5CF6);
      case 'resolved':         return AppColors.resolved;
      case 'reopened':         return AppColors.critical;
      default:                 return AppColors.textMuted;
    }
  }

  Color get statusBg {
    switch (this) {
      case 'received':         return const Color(0xFFEFF6FF);
      case 'in_progress':      return AppColors.mediumLight;
      case 'repair_scheduled': return const Color(0xFFF5F3FF);
      case 'resolved':         return AppColors.lowLight;
      case 'reopened':         return AppColors.criticalLight;
      default:                 return AppColors.surfaceVariant;
    }
  }

  String get statusLabel {
    switch (this) {
      case 'received':         return 'Natanggap';
      case 'in_progress':      return 'Pinoproseso';
      case 'repair_scheduled': return 'Nakaiskedyul';
      case 'resolved':         return 'Nalutas';
      case 'reopened':         return 'Muling Binuka';
      default:                 return this;
    }
  }
}