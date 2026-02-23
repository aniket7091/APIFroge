import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/storage_utils.dart';

/// Manages theme mode: light, dark, or follow-system.
/// Persists the user's choice to SharedPreferences.
class AppThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode;

  AppThemeProvider([ThemeMode initial = ThemeMode.system])
      : _themeMode = initial;

  ThemeMode get themeMode => _themeMode;

  /// true only when explicitly set to dark (not system)
  bool get isDark => _themeMode == ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    StorageUtils.setThemeMode(mode);
  }
}

abstract class AppColors {
  // ── Dark palette ──────────────────────────────────────────────────────────
  static const darkBg = Color(0xFF101622);
  static const darkSurface = Color(0xFF1B2431);
  static const darkCard = Color(0xFF1B2431);
  static const darkBorder = Color(0xFF2D3646);

  // ── Light palette ─────────────────────────────────────────────────────────
  static const lightBg = Color(0xFFF5F6F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE5E7EB);

  // ── Accents ───────────────────────────────────────────────────────────────
  static const accent = Color(0xFF0D59F2);
  static const accentLight = Color(0xFF3B82F6);
  static const accentDark = Color(0xFF1D4ED8);

  // ── HTTP Method colors ────────────────────────────────────────────────────
  static const get = Color(0xFF4CAF50);
  static const post = Color(0xFFFF9800);
  static const put = Color(0xFF2196F3);
  static const patch = Color(0xFF9C27B0);
  static const delete = Color(0xFFF44336);
  static const head = Color(0xFF00BCD4);
  static const options = Color(0xFF795548);

  // ── Status code colors ────────────────────────────────────────────────────
  static const status2xx = Color(0xFF4CAF50);
  static const status3xx = Color(0xFF2196F3);
  static const status4xx = Color(0xFFFF9800);
  static const status5xx = Color(0xFFF44336);
  static const statusError = Color(0xFFF44336);

  // ── Others ─────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFE8E8F0);
  static const textSecondary = Color(0xFF9090A8);
  static const divider = Color(0xFF2A2A30);
}



abstract class AppTheme {
  static ThemeData darkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentLight,
        surface: AppColors.darkSurface,
        error: AppColors.delete,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkSurface,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        bodyMedium: GoogleFonts.inter(color: AppColors.textPrimary),
        bodySmall: GoogleFonts.inter(color: AppColors.textSecondary),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.accent,
        dividerColor: AppColors.darkBorder,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkCard,
        selectedColor: AppColors.accent.withValues(alpha: 0.2),
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  static ThemeData lightTheme() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accentLight,
        surface: AppColors.lightSurface,
        error: AppColors.delete,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.lightSurface,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: Colors.black54,
        indicatorColor: AppColors.accent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  /// Returns the color for the given HTTP method string.
  static Color methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET': return AppColors.get;
      case 'POST': return AppColors.post;
      case 'PUT': return AppColors.put;
      case 'PATCH': return AppColors.patch;
      case 'DELETE': return AppColors.delete;
      case 'HEAD': return AppColors.head;
      case 'OPTIONS': return AppColors.options;
      default: return AppColors.textSecondary;
    }
  }

  /// Returns the color for an HTTP status code.
  static Color statusColor(int code) {
    if (code >= 200 && code < 300) return AppColors.status2xx;
    if (code >= 300 && code < 400) return AppColors.status3xx;
    if (code >= 400 && code < 500) return AppColors.status4xx;
    if (code >= 500) return AppColors.status5xx;
    return AppColors.statusError;
  }
}


