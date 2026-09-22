class AssetTag {
  final String id;
  final String tagNumber;
  final String assetId;
  final String purchaseDate;
  final String deviceType;
  final String itemCategory;
  final String modelName;
  final int quantity;
  final String vendorName;
  final String requestedBy;
  final String purchaseCost;
  final String warrantyExpiry;
  final String department;
  final String notes;
  final String createdAt;
  final String username;
  final String cpu;
  final String motherboard;
  final String storage;
  final String ram;
  final String gpu;

  AssetTag({
    required this.id,
    required this.tagNumber,
    required this.assetId,
    required this.purchaseDate,
    required this.deviceType,
    required this.itemCategory,
    required this.modelName,
    required this.quantity,
    required this.vendorName,
    required this.requestedBy,
    required this.purchaseCost,
    required this.warrantyExpiry,
    required this.department,
    required this.notes,
    required this.createdAt,
    this.username = '',
    this.cpu = '',
    this.motherboard = '',
    this.storage = '',
    this.ram = '',
    this.gpu = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tagNumber': tagNumber,
      'assetId': assetId,
      'purchaseDate': purchaseDate,
      'deviceType': deviceType,
      'itemCategory': itemCategory,
      'modelName': modelName,
      'quantity': quantity,
      'vendorName': vendorName,
      'requestedBy': requestedBy,
      'purchaseCost': purchaseCost,
      'warrantyExpiry': warrantyExpiry,
      'department': department,
      'notes': notes,
      'createdAt': createdAt,
      'username': username,
      'cpu': cpu,
      'motherboard': motherboard,
      'storage': storage,
      'ram': ram,
      'gpu': gpu,
    };
  }

  factory AssetTag.fromMap(Map<dynamic, dynamic> map) {
    return AssetTag(
      id: map['id'] ?? '',
      tagNumber: map['tagNumber'] ?? '',
      assetId: map['assetId'] ?? '',
      purchaseDate: map['purchaseDate'] ?? '',
      deviceType: map['deviceType'] ?? '',
      itemCategory: map['itemCategory'] ?? '',
      modelName: map['modelName'] ?? '',
      quantity: map['quantity'] ?? 1,
      vendorName: map['vendorName'] ?? '',
      requestedBy: map['requestedBy'] ?? '',
      purchaseCost: map['purchaseCost'] ?? '',
      warrantyExpiry: map['warrantyExpiry'] ?? '',
      department: map['department'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] ?? '',
      username: map['username'] ?? '',
      cpu: map['cpu'] ?? '',
      motherboard: map['motherboard'] ?? '',
      storage: map['storage'] ?? '',
      ram: map['ram'] ?? '',
      gpu: map['gpu'] ?? '',
    );
  }

  AssetTag copyWith({
    String? id,
    String? tagNumber,
    String? assetId,
    String? purchaseDate,
    String? deviceType,
    String? itemCategory,
    String? modelName,
    int? quantity,
    String? vendorName,
    String? requestedBy,
    String? purchaseCost,
    String? warrantyExpiry,
    String? department,
    String? notes,
    String? createdAt,
    String? username,
    String? cpu,
    String? motherboard,
    String? storage,
    String? ram,
    String? gpu,
  }) {
    return AssetTag(
      id: id ?? this.id,
      tagNumber: tagNumber ?? this.tagNumber,
      assetId: assetId ?? this.assetId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      deviceType: deviceType ?? this.deviceType,
      itemCategory: itemCategory ?? this.itemCategory,
      modelName: modelName ?? this.modelName,
      quantity: quantity ?? this.quantity,
      vendorName: vendorName ?? this.vendorName,
      requestedBy: requestedBy ?? this.requestedBy,
      purchaseCost: purchaseCost ?? this.purchaseCost,
      warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
      department: department ?? this.department,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      cpu: cpu ?? this.cpu,
      motherboard: motherboard ?? this.motherboard,
      storage: storage ?? this.storage,
      ram: ram ?? this.ram,
      gpu: gpu ?? this.gpu,
    );
  }
}
