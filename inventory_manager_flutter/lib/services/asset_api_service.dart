import 'dart:convert';
import 'package:http/http.dart' as http;

/// Node REST API client for Android APK.
class AssetApiService {
  AssetApiService({required this.token, String? serverUrl, http.Client? client})
      : _client = client ?? http.Client() {
    if (serverUrl != null && serverUrl.isNotEmpty) {
      baseUrl = normalizeUrl(serverUrl);
    }
  }

  static String baseUrl = const String.fromEnvironment('ASSET_API_URL', defaultValue: '');
  final String token;
  final http.Client _client;

  static String normalizeUrl(String url) {
    var cleaned = url.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    return cleaned;
  }

  static Future<bool> pingServer(String serverUrl) async {
    try {
      final normalized = normalizeUrl(serverUrl);
      final response = await http.get(
        Uri.parse('$normalized/health'),
        headers: const {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<String> login(String serverUrl, String email, String password) async {
    final cleanUrl = normalizeUrl(serverUrl);
    baseUrl = cleanUrl;
    
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['token'] is! String) {
      throw AssetApiException((body['error'] as Map?)?['message']?.toString() ?? 'Server sign-in failed.');
    }
    return body['token'] as String;
  }

  Future<AssetLookup> lookup(String tag) async {
    if (baseUrl.isEmpty) throw const AssetApiException('The Server URL is not configured.');
    final response = await _client.get(
      Uri.parse('$baseUrl/api/assets/lookup/${Uri.encodeComponent(tag)}'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    final body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 404) throw const AssetNotFoundException();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AssetApiException((body['error'] as Map?)?['message']?.toString() ?? 'Asset lookup failed.');
    }
    final type = body['type']?.toString();
    final data = body['data'];
    if ((type != 'workstation' && type != 'peripheral') || data is! Map<String, dynamic>) {
      throw const AssetApiException('Invalid lookup response.');
    }
    return AssetLookup(type: type!, data: data);
  }

  Future<dynamic> _get(String path) async {
    if (baseUrl.isEmpty) throw const AssetApiException('The Server URL is not configured.');
    final response = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    return _processResponse(response);
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? data]) async {
    if (baseUrl.isEmpty) throw const AssetApiException('The Server URL is not configured.');
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: data != null ? jsonEncode(data) : null,
    );
    return _processResponse(response);
  }

  Future<dynamic> _patch(String path, [Map<String, dynamic>? data]) async {
    if (baseUrl.isEmpty) throw const AssetApiException('The Server URL is not configured.');
    final response = await _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: data != null ? jsonEncode(data) : null,
    );
    return _processResponse(response);
  }

  Future<dynamic> _delete(String path) async {
    if (baseUrl.isEmpty) throw const AssetApiException('The Server URL is not configured.');
    final response = await _client.delete(
      Uri.parse('$baseUrl$path'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 204) return null;
    return _processResponse(response);
  }

  dynamic _processResponse(http.Response response) {
    if (response.body.isEmpty && response.statusCode == 204) return null;
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 404) throw const AssetNotFoundException();
      final msg = (body is Map && body['error'] is Map) ? body['error']['message']?.toString() : null;
      throw AssetApiException(msg ?? 'API request failed with status ${response.statusCode}.');
    }
    return body;
  }

  Future<List<dynamic>> getWorkstations() async => await _get('/api/workstations') as List<dynamic>;
  Future<List<dynamic>> getPeripherals() async => await _get('/api/peripherals') as List<dynamic>;
  Future<List<dynamic>> getUsers() async => await _get('/api/users') as List<dynamic>;
  Future<List<dynamic>> getLogs() async => await _get('/api/logs') as List<dynamic>;

  Future<Map<String, dynamic>> createWorkstation(Map<String, dynamic> data) async => await _post('/api/workstations', data) as Map<String, dynamic>;
  Future<Map<String, dynamic>> updateWorkstation(String tag, Map<String, dynamic> data) async => await _patch('/api/workstations/${Uri.encodeComponent(tag)}', data) as Map<String, dynamic>;

  Future<Map<String, dynamic>> createPeripheral(Map<String, dynamic> data) async => await _post('/api/peripherals', data) as Map<String, dynamic>;
  Future<Map<String, dynamic>> updatePeripheral(String tag, Map<String, dynamic> data) async => await _patch('/api/peripherals/${Uri.encodeComponent(tag)}', data) as Map<String, dynamic>;

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async => await _post('/api/users', data) as Map<String, dynamic>;
  Future<Map<String, dynamic>> updateUser(String email, Map<String, dynamic> data) async => await _patch('/api/users/${Uri.encodeComponent(email)}', data) as Map<String, dynamic>;
  Future<void> deleteUser(String email) async => await _delete('/api/users/${Uri.encodeComponent(email)}');

  // Personnel API (asset owners — NOT login accounts)
  Future<List<dynamic>> getPersonnel() async => await _get('/api/personnel') as List<dynamic>;
  Future<Map<String, dynamic>> getPersonnelById(String id) async => await _get('/api/personnel/${Uri.encodeComponent(id)}') as Map<String, dynamic>;
  Future<Map<String, dynamic>> createPersonnel(Map<String, dynamic> data) async => await _post('/api/personnel', data) as Map<String, dynamic>;
  Future<Map<String, dynamic>> updatePersonnel(String id, Map<String, dynamic> data) async => await _patch('/api/personnel/${Uri.encodeComponent(id)}', data) as Map<String, dynamic>;
  Future<void> deletePersonnel(String id) async => await _delete('/api/personnel/${Uri.encodeComponent(id)}');

  Future<void> updateAssetStatus(String kind, String tag, String status) async => await _patch('/api/assets/$kind/${Uri.encodeComponent(tag)}/status', {'status': status});
}

class AssetLookup {
  const AssetLookup({required this.type, required this.data});
  final String type;
  final Map<String, dynamic> data;
}

class AssetApiException implements Exception {
  const AssetApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AssetNotFoundException extends AssetApiException {
  const AssetNotFoundException() : super('No asset matches this tag.');
}
