import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_manager_flutter/models/user.dart';
import 'package:inventory_manager_flutter/services/asset_api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  String? _apiToken;
  String _serverUrl = '';

  User? get currentUser => _currentUser;
  String? get apiToken => _apiToken;
  String get serverUrl => _serverUrl;

  Future<void> init() async {
    try {
      final box = await Hive.openBox('settings');
      _serverUrl = box.get('serverUrl', defaultValue: '') as String;
      if (_serverUrl.isNotEmpty) {
        AssetApiService.baseUrl = AssetApiService.normalizeUrl(_serverUrl);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading serverUrl from settings: $e');
    }
  }

  void setApiToken(String? token) {
    _apiToken = token;
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = AssetApiService.normalizeUrl(url);
    AssetApiService.baseUrl = _serverUrl;
    final box = await Hive.openBox('settings');
    await box.put('serverUrl', _serverUrl);
    notifyListeners();
  }

  Future<void> login(String serverUrl, String email, String password) async {
    final cleanUrl = AssetApiService.normalizeUrl(serverUrl);
    _apiToken = await AssetApiService.login(cleanUrl, email, password);
    _serverUrl = cleanUrl;
    
    final box = await Hive.openBox('settings');
    await box.put('serverUrl', _serverUrl);
    notifyListeners();
  }

  void setCurrentUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _apiToken = null;
    notifyListeners();
  }
}
