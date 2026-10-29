import 'package:flutter/material.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/services/api_service.dart';
import 'package:kalasathi_mobile/services/offline_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  String _selectedLanguage = 'mr'; // Default to Marathi for demo or user choice
  String? _authToken;
  Map<String, dynamic>? _artisanProfile;
  bool _isLoading = false;

  String get selectedLanguage => _selectedLanguage;
  String? get authToken => _authToken;
  String? get token => _authToken;
  Map<String, dynamic>? get artisanProfile => _artisanProfile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _authToken != null;

  String getArtisanName(AppLocalizations l10n) {
    final name = _artisanProfile?['name']?.toString()?.trim() ?? '';
    if (name.isEmpty ||
        name.contains('?') ||
        name == 'सुनीता बाई सोनवणे' ||
        name == 'Sunita Bai Sonawane' ||
        name == 'ಸುನೀತಾ ಬಾಯಿ ಸೋನವಣೆ' ||
        name == 'Artisan User' ||
        name == 'Default Artisan') {
      return l10n.translate('artisanNameLocalized');
    }
    return name;
  }

  AuthProvider() {
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final lang = await OfflineStorageService.getSelectedLanguage();
    if (lang != null && lang.isNotEmpty) {
      _selectedLanguage = lang;
    }
    _authToken = await OfflineStorageService.getAuthToken();
    _artisanProfile = await OfflineStorageService.getArtisanProfile();
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    _selectedLanguage = langCode;
    notifyListeners();
    try {
      await OfflineStorageService.saveSelectedLanguage(langCode);
    } catch (_) {}
  }

  Future<String?> sendOtp(String phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.sendOtp(phone);
      _isLoading = false;
      notifyListeners();
      return res['mock_code'] as String?;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return '123456';
    }
  }

  Future<bool> verifyOtp({
    required String phone,
    required String code,
    String? name,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.verifyOtp(
        phone: phone,
        code: code,
        name: name,
        language: _selectedLanguage,
      );
      _authToken = res['access_token'] as String;
      _artisanProfile = {
        'name': res['name'] ?? name ?? 'Artisan',
        'phone': phone,
        'role': 'artisan',
        'artisan_id': res['artisan_id'] ?? 1,
      };
      await OfflineStorageService.saveAuthToken(_authToken!);
      await OfflineStorageService.saveArtisanProfile(_artisanProfile!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile({
    required String craftType,
    required String village,
    required String district,
    required String state,
    String? upiId,
  }) async {
    if (_artisanProfile != null) {
      _artisanProfile!['craft_type'] = craftType;
      _artisanProfile!['village'] = village;
      _artisanProfile!['district'] = district;
      _artisanProfile!['state'] = state;
      _artisanProfile!['upi_id'] = upiId;
      await OfflineStorageService.saveArtisanProfile(_artisanProfile!);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _authToken = null;
    _artisanProfile = null;
    await OfflineStorageService.saveAuthToken('');
    notifyListeners();
  }
}
