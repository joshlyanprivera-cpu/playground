import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  // ─── Color Palette ───
  static const Color _accentLight = Color(0xFF2C2C2C);
  static const Color _surfaceLight = Color(0xFFF7F7F8);
  static const Color _cardLight = Colors.white;
  static const Color _mutedLight = Color(0xFF9E9E9E);

  static const Color _accentDark = Color(0xFFE0E0E0);
  static const Color _surfaceDark = Color(0xFF121212);
  static const Color _cardDark = Color(0xFF1E1E1E);
  static const Color _mutedDark = Color(0xFF757575);

  // ─── Shared Geometry ───
  static final BorderRadius _inputRadius = BorderRadius.circular(14);
  static final BorderRadius _cardRadius = BorderRadius.circular(20);
  static final BorderRadius _buttonRadius = BorderRadius.circular(14);

  // ─── Light Theme ───
  static ThemeData get lightTheme {
    final base = ThemeData(brightness: Brightness.light);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: _accentLight,
      displayColor: _accentLight,
    );

    return base.copyWith(
      scaffoldBackgroundColor: _surfaceLight,
      primaryColor: _accentLight,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _surfaceLight,
        foregroundColor: _accentLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _accentLight,
        ),
        iconTheme: const IconThemeData(color: _accentLight),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _cardLight,
        selectedItemColor: _accentLight,
        unselectedItemColor: _mutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
      ),
      cardTheme: CardThemeData(
        color: _cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _cardRadius,
          side: BorderSide(color: Colors.grey.shade200),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accentLight,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          side: BorderSide(color: Colors.grey.shade400),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: _inputRadius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: _inputRadius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: const BorderSide(color: _accentLight, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: _mutedLight, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: _mutedLight, fontSize: 14),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade100,
        selectedColor: _accentLight,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _accentLight,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
      ),
      colorScheme: ColorScheme.light(
        primary: _accentLight,
        secondary: _accentLight.withAlpha(180),
        surface: _surfaceLight,
        error: const Color(0xFFD32F2F),
      ),
    );
  }

  // ─── Dark Theme ───
  static ThemeData get darkTheme {
    final base = ThemeData(brightness: Brightness.dark);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: _accentDark,
      displayColor: _accentDark,
    );

    return base.copyWith(
      scaffoldBackgroundColor: _surfaceDark,
      primaryColor: _accentDark,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _surfaceDark,
        foregroundColor: _accentDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _accentDark,
        ),
        iconTheme: const IconThemeData(color: _accentDark),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _cardDark,
        selectedItemColor: _accentDark,
        unselectedItemColor: _mutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
      ),
      cardTheme: CardThemeData(
        color: _cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _cardRadius,
          side: BorderSide(color: Colors.grey.shade800),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentDark,
          foregroundColor: _surfaceDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _accentDark,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          side: BorderSide(color: Colors.grey.shade600),
          shape: RoundedRectangleBorder(borderRadius: _buttonRadius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: _inputRadius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: _inputRadius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: const BorderSide(color: _accentDark, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: _mutedDark, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: _mutedDark, fontSize: 14),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade800, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2A2A2A),
        selectedColor: _accentDark,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _accentDark),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _surfaceDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _accentDark,
        contentTextStyle: GoogleFonts.inter(color: _surfaceDark),
      ),
      colorScheme: ColorScheme.dark(
        primary: _accentDark,
        secondary: _accentDark.withAlpha(180),
        surface: _surfaceDark,
        error: const Color(0xFFEF5350),
      ),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode');
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }
}
