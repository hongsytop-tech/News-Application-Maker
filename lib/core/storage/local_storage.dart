import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A small typed facade over [SharedPreferences].
///
/// Every feature persists its state through this single instance so the storage
/// pattern (lazy-initialised singleton + JSON encoding for collections) stays
/// consistent across modules.
class LocalStorage {
  LocalStorage._(this._prefs);

  final SharedPreferences _prefs;

  static LocalStorage? _instance;

  static Future<LocalStorage> getInstance() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    return _instance = LocalStorage._(prefs);
  }

  // --- Primitive helpers -------------------------------------------------

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  // --- JSON helpers ------------------------------------------------------

  /// Reads a list of JSON objects stored under [key]. Returns an empty list
  /// when nothing is stored or the payload is corrupt.
  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));
}
