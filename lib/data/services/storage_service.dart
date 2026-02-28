import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_model.dart';

class StorageService {
  static const _serverUrlKey = 'IP_ADDRESS';
  static const _apiKeyKey = 'API-KEY';
  static const _printersKey = 'printers';
  static const _printAreasKey = 'print_areas';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Server URL ─────────────────────────────────────────
  String get serverUrl => _prefs.getString(_serverUrlKey) ?? '';
  Future<bool> setServerUrl(String url) => _prefs.setString(_serverUrlKey, url);

  // ─── API Key ────────────────────────────────────────────
  String get apiKey => _prefs.getString(_apiKeyKey) ?? '';
  Future<bool> setApiKey(String key) => _prefs.setString(_apiKeyKey, key);

  // ─── Print Areas ────────────────────────────────────────
  List<String> get printAreas =>
      _prefs.getStringList(_printAreasKey) ?? ['kitchen', 'cashier'];
  Future<bool> setPrintAreas(List<String> areas) =>
      _prefs.setStringList(_printAreasKey, areas);

  // ─── Printers ───────────────────────────────────────────
  List<PrinterModel> get printers {
    final raw = _prefs.getString(_printersKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PrinterModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> savePrinters(List<PrinterModel> printers) {
    final json = jsonEncode(printers.map((e) => e.toJson()).toList());
    return _prefs.setString(_printersKey, json);
  }
}
