import 'package:flutter/material.dart';

class AppTheme {
  static const _bg = Color(0xFF0B0F10);        // background i errët
  static const _surface = Color(0xFF11181A);   // panels
  static const _card = Color(0xFF1A2224);      // cards
  static const _card2 = Color(0xFF202A2D);     // hover/alt
  static const _teal = Color(0xFF00C2A8);      // accent (si në foto)
  static const _border = Color(0xFF2B3A3E);    // borders
  static const _text = Color(0xFFEAF2F2);
  static const _muted = Color(0xFF9FB3B6);

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: _teal,
      brightness: Brightness.dark,
      surface: _surface,
      background: _bg,
    ).copyWith(
      primary: _teal,
      secondary: _teal,
      error: const Color(0xFFFF5C5C),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,

      scaffoldBackgroundColor: _bg,

      // Teksti
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _text),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _text),
        bodyMedium: TextStyle(fontSize: 14, color: _text),
        bodySmall: TextStyle(fontSize: 12, color: _muted),
      ),

      // Cards
      cardTheme: const CardThemeData(
        color: _card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: _border),
        ),
      ),


      // Divider
      dividerTheme: const DividerThemeData(color: _border, thickness: 1),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _text,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _text,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // TextFields (kjo e rregullon “default fieldat”)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _card2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: const TextStyle(color: _muted),
        hintStyle: const TextStyle(color: _muted),
        floatingLabelStyle: const TextStyle(color: _teal, fontWeight: FontWeight.w600),
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
          borderSide: const BorderSide(color: _teal, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF5C5C)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF5C5C), width: 1.6),
        ),
      ),

      // NavRail (sidebar)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF0F1516),
        selectedIconTheme: const IconThemeData(color: _teal),
        unselectedIconTheme: const IconThemeData(color: _muted),
        selectedLabelTextStyle: const TextStyle(color: _teal, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: const TextStyle(color: _muted),
        indicatorColor: _card2,
      ),

      // DataTable
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(color: _muted, fontWeight: FontWeight.w700),
        dataTextStyle: TextStyle(color: _text),
        dividerThickness: 1,
      ),

      // Scrollbar (si në foto)
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(_border),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(12),
        thickness: WidgetStateProperty.all(10),
      ),

      // Tabs/segmented
      tabBarTheme: const TabBarThemeData(
        labelColor: _teal,
        unselectedLabelColor: _muted,
        indicatorColor: _teal,
      ),

    );
  }
}
