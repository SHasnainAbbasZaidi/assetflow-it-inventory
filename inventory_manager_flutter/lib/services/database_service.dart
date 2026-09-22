import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_manager_flutter/models/asset.dart';
import 'package:inventory_manager_flutter/models/asset_tag.dart';
import 'package:inventory_manager_flutter/models/user.dart';
import 'package:inventory_manager_flutter/models/personnel.dart';
import 'package:inventory_manager_flutter/models/activity_log.dart';
import 'package:csv/csv.dart';
import 'package:inventory_manager_flutter/services/asset_api_service.dart';

class InventoryProvider extends ChangeNotifier {
  late Box _settingsBox;

  List<Asset> _workstations = [];
  List<Asset> _peripherals = [];
  
  // Tag customization config
  Map<String, dynamic> _tagConfig = {
    'showDeviceName': true,
    'showUser': true,
    'showCompany': true,
    'qrSize': 100.0,
  };

  // Custom Fields config
  List<Map<String, dynamic>> _customFieldsConfig = [];

  List<AssetTag> _tags = [];
  List<User> _users = [];
  List<Personnel> _personnel = [];
  List<ActivityLog> _logs = [];
  String _companyLogo = '';
  String _companyName = '';
  String _companyAddress = '';
  String _geminiApiKey = '';
  bool _initialized = false;
  String? _token;

  List<Asset> get workstations => _workstations;
  List<Asset> get peripherals => _peripherals;
  List<Asset> get assets => [..._workstations, ..._peripherals];
  List<AssetTag> get tags => _tags;
  List<User> get users => _users;
  List<Personnel> get personnel => _personnel;
  List<ActivityLog> get logs => _logs;
  String get companyLogo => _companyLogo;
  String get companyName => _companyName;
  String get companyAddress => _companyAddress;
  String get geminiApiKey => _geminiApiKey;
  bool get initialized => _initialized;
  Map<String, dynamic> get tagConfig => _tagConfig;
  List<Map<String, dynamic>> get customFieldsConfig => _customFieldsConfig;

  Future<void> init() async {
    if (_initialized) return;

    _settingsBox = await Hive.openBox('settings');
    _companyLogo = _settingsBox.get('companyLogo', defaultValue: '') as String;
    _companyName = _settingsBox.get('companyName', defaultValue: '') as String;
    _companyAddress = _settingsBox.get('companyAddress', defaultValue: '') as String;
    _geminiApiKey = _settingsBox.get('geminiApiKey', defaultValue: '') as String;
    
    final savedTagConfig = _settingsBox.get('tagConfig');
    if (savedTagConfig != null && savedTagConfig is Map) {
      _tagConfig = Map<String, dynamic>.from(savedTagConfig);
    }
    
    final savedCustomFields = _settingsBox.get('customFieldsConfig');
    if (savedCustomFields != null && savedCustomFields is List) {
      _customFieldsConfig = List<Map<String, dynamic>>.from(savedCustomFields.map((e) => Map<String, dynamic>.from(e)));
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> saveTagConfig(Map<String, dynamic> config) async {
    _tagConfig = config;
    await _settingsBox.put('tagConfig', config);
    notifyListeners();
  }

  Future<void> saveCustomFieldsConfig(List<Map<String, dynamic>> config) async {
    _customFieldsConfig = config;
    await _settingsBox.put('customFieldsConfig', config);
    notifyListeners();
  }

  String _mapStatus(String s) {
    if (s == 'IN_STORE') return 'In Store';
    if (s == 'OUT_OF_ORDER') return 'Out of Order';
    if (s == 'ASSIGNED') return 'Assigned';
    if (s == 'RETIRED') return 'Retired';
    return 'In Store';
  }

  String _unmapStatus(String s) {
    if (s == 'In Store') return 'IN_STORE';
    if (s == 'Out of Order') return 'OUT_OF_ORDER';
    if (s == 'Assigned') return 'ASSIGNED';
    if (s == 'Retired') return 'RETIRED';
    return 'IN_STORE';
  }

  Future<void> syncWithServer(String token) async {
    _token = token;
    final api = AssetApiService(token: token);
    
    final wData = await api.getWorkstations();
    final pData = await api.getPeripherals();
    final personnelData = await api.getPersonnel();
    final lData = await api.getLogs();

    // Users (/api/users) is Admin-only. Gracefully handle 403.
    try {
      final uData = await api.getUsers();
      _users = uData.map((e) => User(
        id: e['email'] ?? '', 
        name: e['fullName'] ?? 'Unknown', 
        department: e['role'] ?? 'User', 
        email: e['email'] ?? '', 
        password: '', 
        isAdmin: e['role'] == 'ADMIN'
      )).toList();
    } catch (_) {
      // Non-admin users can't read /api/users — keep existing list
      debugPrint('Skipped /api/users sync (non-admin or network error)');
    }

    // Personnel — always available to all authenticated users
    _personnel = personnelData.map((e) => Personnel.fromJson(e as Map<String, dynamic>)).toList();

    _workstations = [];
    _peripherals = [];
    _tags = [];

    for (final w in wData) {
      final tag = w['workstationTag'] ?? '';
      _workstations.add(Asset(
        id: tag,
        name: tag,
        category: 'Workstation',
        serial: '',
        status: _mapStatus(w['status'] ?? ''),
        assignee: w['userName'] ?? '', 
        customFields: w['custom_fields'] ?? w,
        dateAdded: w['assignedDate']?.toString().split('T')[0] ?? '',
      ));
      _tags.add(AssetTag(
        id: tag, tagNumber: tag, assetId: tag, purchaseDate: w['assignedDate']?.toString().split('T')[0] ?? '', 
        deviceType: w['deviceType'] ?? 'Workstation', itemCategory: 'Workstation', 
        modelName: tag, quantity: 1, vendorName: '', requestedBy: '', purchaseCost: '', 
        warrantyExpiry: '', department: '', notes: w['notes'] ?? '', createdAt: '', 
        username: w['userName'] ?? '', cpu: w['processorGen'] ?? '', motherboard: w['motherboard'] ?? '', 
        storage: w['ssd'] ?? '', ram: w['ram'] ?? '', gpu: w['gpu'] ?? ''
      ));
    }

    for (final p in pData) {
      final tag = p['peripheralTag'] ?? '';
      _peripherals.add(Asset(
        id: tag,
        name: tag,
        category: p['category'] ?? 'Peripheral',
        serial: '',
        status: _mapStatus(p['status'] ?? ''),
        assignee: p['workstationTag'] ?? '',
        customFields: p['custom_fields'] ?? p,
        dateAdded: p['purchaseDate']?.toString().split('T')[0] ?? '',
      ));
      _tags.add(AssetTag(
        id: tag, tagNumber: tag, assetId: tag, purchaseDate: p['purchaseDate']?.toString().split('T')[0] ?? '', 
        deviceType: p['brandManufacturer'] ?? 'Peripheral', itemCategory: p['category'] ?? 'Peripheral', 
        modelName: p['modelSpecs'] ?? '', quantity: p['quantity'] ?? 1, vendorName: '', requestedBy: '', 
        purchaseCost: '', warrantyExpiry: p['warrantyExpiry']?.toString().split('T')[0] ?? '', 
        department: '', notes: '', createdAt: '', username: '', cpu: '', motherboard: '', 
        storage: p['storageCapacity'] ?? '', ram: '', gpu: p['gpuSpecs'] ?? ''
      ));
    }

    _logs = lData.map((e) => ActivityLog(
      id: e['logId'] ?? '',
      timestamp: e['timestamp'] ?? '',
      user: e['userEmail'] ?? 'System',
      action: e['actionTaken'] ?? '',
      assetId: e['assetTag'] ?? '',
      details: '',
    )).toList();

    notifyListeners();
  }

  String _generateShortId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> logActivity(String action, String assetId, String details) async {
    notifyListeners();
  }

  Future<List<String>> bulkAddTagAssets({
    required String category,
    required String model,
    required int quantity,
  }) async {
    return await generateAssetTags(
        purchaseDate: DateTime.now().toIso8601String(), 
        deviceType: category, 
        itemCategory: category, 
        modelName: model, 
        quantity: quantity);
  }

  Future<void> addAsset({
    required String name,
    required String category,
    required String serial,
    required String status,
    required String assignee,
    required Map<String, dynamic> customFields,
  }) async {
    if (_token == null) return;
    final api = AssetApiService(token: _token!);
    final id = _generateShortId();
    if (category.toLowerCase() == 'workstation') {
      await api.createWorkstation({
        'workstationTag': id,
        'userName': assignee.isEmpty ? null : assignee,
        'deviceType': customFields['deviceType'],
        'motherboard': customFields['motherboard'],
        'processorGen': customFields['cpu'],
        'ram': customFields['ram'],
        'ssd': customFields['storage'],
        'gpu': customFields['gpu'],
        'notes': customFields['notes'],
        'custom_fields': customFields,
      });
    } else {
      await api.createPeripheral({
        'peripheralTag': id,
        'category': category,
        'modelSpecs': customFields['model'],
        'workstationTag': assignee.isEmpty ? null : assignee,
        'brandManufacturer': customFields['deviceType'],
        'storageCapacity': customFields['storage'],
        'gpuSpecs': customFields['gpu'],
        'quantity': 1,
        'custom_fields': customFields,
      });
    }
    await syncWithServer(_token!);
  }

  Future<void> updateAsset(String id, {
    required String name,
    required String category,
    required String serial,
    required String status,
    required String assignee,
    required Map<String, dynamic> customFields,
  }) async {
    if (_token == null) return;
    final api = AssetApiService(token: _token!);
    
    final oldAsset = assets.firstWhere((a) => a.id == id);
    if (oldAsset.status != status) {
      await api.updateAssetStatus(oldAsset.category.toLowerCase() == 'workstation' ? 'workstation' : 'peripheral', id, _unmapStatus(status));
    }
    
    if (category.toLowerCase() == 'workstation') {
      await api.updateWorkstation(id, {
        'userName': assignee.isEmpty ? null : assignee,
        'deviceType': customFields['deviceType'],
        'motherboard': customFields['motherboard'],
        'processorGen': customFields['cpu'],
        'ram': customFields['ram'],
        'ssd': customFields['storage'],
        'gpu': customFields['gpu'],
        'notes': customFields['notes'],
        'custom_fields': customFields,
      });
    } else {
      await api.updatePeripheral(id, {
        'category': category,
        'modelSpecs': customFields['model'],
        'workstationTag': assignee.isEmpty ? null : assignee,
        'brandManufacturer': customFields['deviceType'],
        'storageCapacity': customFields['storage'],
        'gpuSpecs': customFields['gpu'],
        'custom_fields': customFields,
      });
    }
    await syncWithServer(_token!);
  }

  Future<void> deleteAsset(String id) async {
    if (_token == null) return;
    final api = AssetApiService(token: _token!);
    final asset = assets.firstWhere((a) => a.id == id);
    if (asset.status != 'Retired') {
      await api.updateAssetStatus(asset.category.toLowerCase() == 'workstation' ? 'workstation' : 'peripheral', id, 'RETIRED');
      await syncWithServer(_token!);
    }
  }

  Future<List<String>> generateAssetTags({
    required String purchaseDate,
    required String deviceType,
    required String itemCategory,
    required String modelName,
    required int quantity,
    String vendorName = '',
    String requestedBy = '',
    String purchaseCost = '',
    String warrantyExpiry = '',
    String department = '',
    String notes = '',
    String username = '',
    String cpu = '',
    String motherboard = '',
    String storage = '',
    String ram = '',
    String gpu = '',
  }) async {
    if (_token == null) return [];
    final api = AssetApiService(token: _token!);
    final ids = <String>[];
    for (int i = 0; i < quantity; i++) {
      String id;
      do { id = _generateShortId(); } while (assets.any((a) => a.id == id) || ids.contains(id));
      
      if (itemCategory.toLowerCase() == 'workstation') {
        await api.createWorkstation({
          'workstationTag': id,
          'deviceType': deviceType,
          'motherboard': motherboard,
          'processorGen': cpu,
          'ram': ram,
          'ssd': storage,
          'gpu': gpu,
          'notes': notes,
          'userName': username.isEmpty ? null : username,
          'assignedDate': purchaseDate.isEmpty ? null : purchaseDate,
        });
      } else {
        await api.createPeripheral({
          'peripheralTag': id,
          'category': itemCategory,
          'modelSpecs': modelName,
          'brandManufacturer': deviceType,
          'storageCapacity': storage,
          'gpuSpecs': gpu,
          'quantity': 1,
          'purchaseDate': purchaseDate.isEmpty ? null : purchaseDate,
        });
      }
      ids.add(id);
    }
    await syncWithServer(_token!);
    return ids;
  }

  AssetTag? getTagByAssetId(String assetId) {
    return _tags.where((t) => t.assetId == assetId).firstOrNull;
  }

  AssetTag? getTagByTagNumber(String tagNumber) {
    return _tags.where((t) => t.tagNumber == tagNumber).firstOrNull;
  }

  // =====================================================================
  // PERSONNEL CRUD (asset owners — real people, NOT login accounts)
  // =====================================================================
  Future<void> addPersonnel({
    required String fullName,
    String department = '',
    String contactEmail = '',
    String notes = '',
  }) async {
    if (_token == null) return;
    final api = AssetApiService(token: _token!);
    await api.createPersonnel({
      'fullName': fullName,
      'department': department.isEmpty ? null : department,
      'contactEmail': contactEmail.isEmpty ? null : contactEmail,
      'notes': notes.isEmpty ? null : notes,
    });
    await syncWithServer(_token!);
  }

  Future<void> updatePersonnel(String id, {
    required String fullName,
    String department = '',
    String contactEmail = '',
    String notes = '',
  }) async {
    if (_token == null) return;
    final api = AssetApiService(token: _token!);
    await api.updatePersonnel(id, {
      'fullName': fullName,
      'department': department.isEmpty ? null : department,
      'contactEmail': contactEmail.isEmpty ? null : contactEmail,
      'notes': notes.isEmpty ? null : notes,
    });
    await syncWithServer(_token!);
  }

  Future<void> deletePersonnel(String id) async {
    if (_token == null) return;
    final api = AssetApiService(token: _token!);
    await api.deletePersonnel(id);
    await syncWithServer(_token!);
  }

  // =====================================================================
  // APP USERS CRUD (login accounts — Admin only)
  // =====================================================================
  Future<void> addUser({
    String? id,
    required String name,
    required String department,
    required String email,
    required String password,
    required bool isAdmin,
    bool isSeed = false,
  }) async {
    if (_token == null) return;
    final api = AssetApiService(token: _token!);
    await api.createUser({
      'email': email,
      'fullName': name,
      'role': isAdmin ? 'ADMIN' : department,
      'status': 'ACTIVE',
      'password': password,
    });
    if (!isSeed) await syncWithServer(_token!);
  }

  Future<void> updateUser(String id, {
    required String name,
    required String department,
    required String email,
  }) async {
    if (_token == null) return;
    final api = AssetApiService(token: _token!);
    await api.updateUser(id, {
      'fullName': name,
      'role': department,
    });
    await syncWithServer(_token!);
  }

  Future<void> updateAppUser(String id, {
    required String name,
    required String email,
    required String department,
    required String password,
    required bool isAdmin,
  }) async {
    if (_token == null) return;
    final api = AssetApiService(token: _token!);
    await api.updateUser(id, {
      'fullName': name,
      'role': isAdmin ? 'ADMIN' : department,
      'password': password,
    });
    await syncWithServer(_token!);
  }

  Future<void> deleteUser(String id) async {
    if (id == 'unassigned') return;
    if (_token == null) return;
    final api = AssetApiService(token: _token!);
    await api.deleteUser(id);
    await syncWithServer(_token!);
  }

  Future<void> saveBrandingLogo(String base64Logo) async {
    _companyLogo = base64Logo;
    await _settingsBox.put('companyLogo', base64Logo);
    notifyListeners();
  }

  Future<void> saveCompanyDetails(String name, String address) async {
    _companyName = name;
    _companyAddress = address;
    await _settingsBox.put('companyName', name);
    await _settingsBox.put('companyAddress', address);
    notifyListeners();
  }

  Future<void> saveGeminiApiKey(String key) async {
    _geminiApiKey = key;
    await _settingsBox.put('geminiApiKey', key);
    notifyListeners();
  }

  String getCSVContent() {
    return ""; // Unused by new system
  }

  Future<void> importAssetsFromCSV(String csvString, {String? targetType}) async {
    // Relying on backend excel importer for mass data syncs instead of flutter client
    notifyListeners();
  }
}
