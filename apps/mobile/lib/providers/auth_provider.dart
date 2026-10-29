import 'package:flutter/material.dart';
import 'package:kalasathi_mobile/l10n/app_localizations.dart';
import 'package:kalasathi_mobile/services/api_service.dart';
import 'package:kalasathi_mobile/services/offline_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  String _selectedLanguage = 'mr'; // Default to Marathi for demo or user choice
  String? _authToken;
  Map<String, dynamic>? _artisanProfile;
  bool _isLoading = false;
  String? _lastAuthError;

  String get selectedLanguage => _selectedLanguage;
  String? get authToken => _authToken;
  String? get token => _authToken;
  Map<String, dynamic>? get artisanProfile => _artisanProfile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _authToken != null;
  String? get lastAuthError => _lastAuthError;

  String getArtisanName(AppLocalizations l10n) {
    final name = _artisanProfile?['name']?.toString().trim() ?? '';
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

  Future<bool> authenticateWithPassword({
    required String identifier,
    required String password,
    required bool isSignUp,
    String? name,
  }) async {
    _isLoading = true;
    _lastAuthError = null;
    notifyListeners();
    try {
      final normalizedIdentifier =
          identifier.contains('@') || identifier.startsWith('+')
              ? identifier
              : '+91${identifier.replaceAll(RegExp(r'\s+'), '')}';
      final response = isSignUp
          ? await ApiService.registerArtisan(
              name: name!.trim(),
              phone: normalizedIdentifier,
              password: password,
            )
          : await ApiService.loginWithPassword(
              identifier: normalizedIdentifier,
              password: password,
            );
      if (response['is_artisan'] != true || response['artisan_id'] == null) {
        throw Exception('This account is not registered as an artisan.');
      }
      _authToken = response['access_token'] as String;
      _artisanProfile = {
        'name': response['name'] ?? name ?? 'Artisan',
        'phone': normalizedIdentifier,
        'role': 'artisan',
        'artisan_id': response['artisan_id'],
      };
      await OfflineStorageService.saveAuthToken(_authToken!);
      await OfflineStorageService.saveArtisanProfile(_artisanProfile!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _lastAuthError = error.toString().replaceFirst('Exception: ', '');
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
