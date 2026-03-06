/// ReseAgenten – Applikationstemat
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ─── Färgpalett ───────────────────────────────────────────────────────────
  static const _seedColor = Color(0xFF0054A3); // SL-blå variant
  static const _accentGreen = Color(0xFF00843D); // Kollektivtrafik grön
  static const _alertOrange = Color(0xFFE87722);
  static const _errorRed = Color(0xFFB71C1C);
  static const _surfaceLight = Color(0xFFF5F7FA);
  static const _cardLight = Color(0xFFFFFFFF);
  static const _surfaceDark = Color(0xFF1A1D23);
  static const _cardDark = Color(0xFF252932);

  // ─── Ljust tema ───────────────────────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: _seedColor,
      brightness: Brightness.light,
    );
    return base.copyWith(
      scaffoldBackgroundColor: _surfaceLight,
      cardColor: _cardLight,
      textTheme: _textTheme(base.textTheme, Brightness.light),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: _seedColor,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: _cardLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _seedColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _seedColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _seedColor.withValues(alpha: 0.1),
        labelStyle: const TextStyle(color: _seedColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // ─── Mörkt tema ───────────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: _seedColor,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      scaffoldBackgroundColor: _surfaceDark,
      cardColor: _cardDark,
      textTheme: _textTheme(base.textTheme, Brightness.dark),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: _cardDark,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: _cardDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _seedColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Brightness brightness) {
    final textColor =
        brightness == Brightness.light ? const Color(0xFF1A1D23) : Colors.white;
    return GoogleFonts.interTextTheme(base).copyWith(
      bodyLarge: GoogleFonts.inter(
          fontSize: 15, color: textColor, height: 1.5),
      bodyMedium: GoogleFonts.inter(
          fontSize: 13, color: textColor, height: 1.5),
      titleLarge: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
      titleMedium: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
      titleSmall: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
      labelSmall: GoogleFonts.inter(
          fontSize: 11, color: textColor.withValues(alpha: 0.6)),
    );
  }

  // ─── Semantiska färger ────────────────────────────────────────────────────
  static const successColor = _accentGreen;
  static const warningColor = _alertOrange;
  static const errorColor = _errorRed;
  static const brandBlue = _seedColor;

  static Color modeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'bus':
        return const Color(0xFF0054A3);
      case 'train':
        return const Color(0xFF003F87);
      case 'tram':
        return const Color(0xFF008A5B);
      case 'subway':
        return const Color(0xFF7B1FA2);
      case 'ferry':
        return const Color(0xFF0288D1);
      case 'walk':
        return const Color(0xFF757575);
      default:
        return const Color(0xFF546E7A);
    }
  }

  static String modeLabel(String mode) {
    switch (mode.toLowerCase()) {
      case 'bus':
        return 'Buss';
      case 'train':
        return 'Tåg';
      case 'tram':
        return 'Spårvagn';
      case 'subway':
        return 'Tunnelbana';
      case 'ferry':
        return 'Färja';
      case 'walk':
        return 'Promenad';
      default:
        return 'Okänd';
    }
  }

  static IconData modeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'train':
        return Icons.train_rounded;
      case 'tram':
        return Icons.tram_rounded;
      case 'subway':
        return Icons.subway_rounded;
      case 'ferry':
        return Icons.directions_ferry_rounded;
      case 'walk':
        return Icons.directions_walk_rounded;
      default:
        return Icons.transit_enterexit_rounded;
    }
  }
}
