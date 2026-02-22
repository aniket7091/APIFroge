import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// Utility wrapper around SharedPreferences for persistent storage.
abstract class StorageUtils {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Auth token ─────────────────────────────────────────────────────────────
  static const _tokenKey = 'auth_token';

  static String? getToken() => _prefs.getString(_tokenKey);

  static Future<void> setToken(String token) => _prefs.setString(_tokenKey, token);

  static Future<void> removeToken() => _prefs.remove(_tokenKey);

  // ── Environment variables ──────────────────────────────────────────────────
  static const _envKey = 'env_variables';

  static Map<String, String> getEnvVariables() {
    final raw = _prefs.getString(_envKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final entries = raw.split('\n');
      final map = <String, String>{};
      for (final entry in entries) {
        final idx = entry.indexOf('=');
        if (idx > 0) {
          map[entry.substring(0, idx)] = entry.substring(idx + 1);
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> setEnvVariables(Map<String, String> vars) {
    final raw = vars.entries.map((e) => '${e.key}=${e.value}').join('\n');
    return _prefs.setString(_envKey, raw);
  }

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const _themeModeKey = 'theme_mode';

  static ThemeMode getThemeMode() {
    final saved = _prefs.getString(_themeModeKey) ?? 'system';
    switch (saved) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) {
    final value = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system';
    return _prefs.setString(_themeModeKey, value);
  }
}

