import 'package:flutter/material.dart';

class AppTheme {
  // Steam-like dark palette
  static const _bg = Color(0xFF1B2838); // main background
  static const _surface = Color(0xFF171A21); // panels / sidebar / top areas
  static const _card = Color(0xFF223246); // cards
  static const _card2 = Color(0xFF2A475E); // alt / inputs / hover
  static const _accent = Color(0xFF66C0F4); // Steam blue
  static const _border = Color(0xFF3B4B5F); // borders
  static const _text = Color(0xFFC7D5E0); // main text
  static const _muted = Color(0xFF8F98A0); // secondary text

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.dark,
      surface: _surface,
      background: _bg,
    ).copyWith(
      primary: _accent,
      secondary: _accent,
      error: const Color(0xFFE74C3C),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: _bg,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: _text,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _text,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: _text,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: _muted,
        ),
      ),
      cardTheme: const CardThemeData(
        color: _card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: _border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _border,
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: const Color(0xFF0B141C),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _text,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _card2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: const TextStyle(color: _muted),
        hintStyle: const TextStyle(color: _muted),
        floatingLabelStyle: const TextStyle(
          color: _accent,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE74C3C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE74C3C), width: 1.6),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _surface,
        selectedIconTheme: const IconThemeData(color: _accent),
        unselectedIconTheme: const IconThemeData(color: _muted),
        selectedLabelTextStyle: const TextStyle(
          color: _accent,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(color: _muted),
        indicatorColor: _card2,
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          color: _muted,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: TextStyle(color: _text),
        dividerThickness: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(_border),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(12),
        thickness: WidgetStateProperty.all(10),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: _accent,
        unselectedLabelColor: _muted,
        indicatorColor: _accent,
      ),
    );
  }
}
