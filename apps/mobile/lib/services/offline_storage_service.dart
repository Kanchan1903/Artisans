import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineStorageService {
  static const String _kDraftsKey = 'kalasathi_offline_drafts';
  static const String _kLanguageKey = 'kalasathi_selected_language';
  static const String _kTokenKey = 'kalasathi_auth_token';
  static const String _kArtisanProfileKey = 'kalasathi_artisan_profile';

  static Future<void> saveSelectedLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageKey, langCode);
  }

  static Future<String?> getSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLanguageKey);
  }

  static Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  static Future<void> saveArtisanProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kArtisanProfileKey, jsonEncode(profile));
  }

  static Future<Map<String, dynamic>?> getArtisanProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kArtisanProfileKey);
    if (str != null) {
      return jsonDecode(str) as Map<String, dynamic>;
    }
    return null;
  }

  // ─── Offline Product Queue & Sync Engine ───────────────────────────────────
  static Future<void> queueOfflineProduct(Map<String, dynamic> product) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getOfflineDrafts();
    // Ensure draft has a unique local ID and timestamp
    final draftItem = Map<String, dynamic>.from(product);
    draftItem['_local_id'] = draftItem['_local_id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    draftItem['_queued_at'] = DateTime.now().toIso8601String();
    drafts.add(draftItem);
    await prefs.setString(_kDraftsKey, jsonEncode(drafts));
  }

  static Future<List<Map<String, dynamic>>> getOfflineDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_kDraftsKey);
    if (str != null) {
      final list = jsonDecode(str) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  static Future<int> getQueueCount() async {
    final drafts = await getOfflineDrafts();
    return drafts.length;
  }

  static Future<void> removeOfflineDraft(String localId) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = await getOfflineDrafts();
    drafts.removeWhere((item) => item['_local_id'] == localId);
    await prefs.setString(_kDraftsKey, jsonEncode(drafts));
  }

  static Future<void> clearOfflineDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDraftsKey);
  }

  /// Synchronize all pending offline products with the backend API
  static Future<Map<String, int>> syncOfflineQueue(dynamic apiService) async {
    final drafts = await getOfflineDrafts();
    if (drafts.isEmpty) return {'synced': 0, 'failed': 0};

    int synced = 0;
    int failed = 0;

    for (final draft in List<Map<String, dynamic>>.from(drafts)) {
      try {
        final cleanPayload = Map<String, dynamic>.from(draft);
        final localId = cleanPayload.remove('_local_id');
        cleanPayload.remove('_queued_at');

        final success = await apiService.publishProduct(cleanPayload);
        if (success) {
          if (localId != null) {
            await removeOfflineDraft(localId.toString());
          }
          synced++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }

    return {'synced': synced, 'failed': failed};
  }
}
