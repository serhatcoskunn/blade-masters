import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyNickname = 'orbitblade_nickname';
  static const String _keyGold = 'orbitblade_gold';
  static const String _keyEquippedBlade = 'orbitblade_blade';
  static const String _keyOwnedBlades = 'orbitblade_owned_blades';
  static const String _keySelectedMap = 'orbitblade_map';
  static const String _keyServerUrl = 'orbitblade_server_url';
  static const String _keyBotCount = 'orbitblade_bot_count';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String getNickname() {
    return _prefs.getString(_keyNickname) ?? 'BladeMaster';
  }

  static Future<void> setNickname(String name) async {
    await _prefs.setString(_keyNickname, name);
  }

  static int getGold() {
    return _prefs.getInt(_keyGold) ?? 200; // Starting bonus
  }

  static Future<void> addGold(int amount) async {
    final current = getGold();
    await _prefs.setInt(_keyGold, current + amount);
  }

  static Future<bool> spendGold(int amount) async {
    final current = getGold();
    if (current >= amount) {
      await _prefs.setInt(_keyGold, current - amount);
      return true;
    }
    return false;
  }

  static String getEquippedBlade() {
    return _prefs.getString(_keyEquippedBlade) ?? 'steel';
  }

  static Future<void> setEquippedBlade(String id) async {
    await _prefs.setString(_keyEquippedBlade, id);
  }

  static List<String> getOwnedBlades() {
    return _prefs.getStringList(_keyOwnedBlades) ?? ['steel'];
  }

  static Future<void> addOwnedBlade(String id) async {
    final list = getOwnedBlades();
    if (!list.contains(id)) {
      list.add(id);
      await _prefs.setStringList(_keyOwnedBlades, list);
    }
  }

  static String getSelectedMap() {
    return _prefs.getString(_keySelectedMap) ?? 'temple';
  }

  static Future<void> setSelectedMap(String id) async {
    await _prefs.setString(_keySelectedMap, id);
  }

  static String getServerUrl() {
    final saved = _prefs.getString(_keyServerUrl);
    if (saved != null && saved.trim().isNotEmpty && saved != 'ws://localhost:2567') {
      return saved.trim();
    }
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost') {
        final scheme = Uri.base.scheme == 'https' ? 'wss' : 'ws';
        final port = Uri.base.hasPort && Uri.base.port != 80 && Uri.base.port != 443 ? ':${Uri.base.port}' : '';
        return '$scheme://$host$port';
      }
    }
    return saved ?? 'ws://localhost:2567';
  }

  static Future<void> setServerUrl(String url) async {
    await _prefs.setString(_keyServerUrl, url);
  }

  static int getBotCount() {
    return _prefs.getInt(_keyBotCount) ?? 3;
  }

  static Future<void> setBotCount(int count) async {
    await _prefs.setInt(_keyBotCount, count.clamp(0, 10));
  }
}
