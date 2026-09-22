class Asset {
  final String id;
  final String name;
  final String category;
  final String serial;
  final String status;
  final String assignee; // User ID or empty/null
  final Map<String, dynamic> customFields;
  final String dateAdded;

  Asset({
    required this.id,
    required this.name,
    required this.category,
    required this.serial,
    required this.status,
    required this.assignee,
    required this.customFields,
    required this.dateAdded,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'serial': serial,
      'status': status,
      'assignee': assignee,
      'customFields': customFields,
      'dateAdded': dateAdded,
    };
  }

  factory Asset.fromMap(Map<dynamic, dynamic> map) {
    final storedStatus = map['status']?.toString() ?? 'In Store';
    final normalizedStatus = switch (storedStatus) {
      'Available' => 'In Store',
      'In Use' => 'Assigned',
      'Maintenance' => 'Out of Order',
      _ => storedStatus,
    };
    return Asset(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      serial: map['serial'] ?? '',
      status: normalizedStatus,
      assignee: map['assignee'] ?? '',
      customFields: Map<String, dynamic>.from(map['customFields'] ?? {}),
      dateAdded: map['dateAdded'] ?? '',
    );
  }

  Asset copyWith({
    String? id,
    String? name,
    String? category,
    String? serial,
    String? status,
    String? assignee,
    Map<String, dynamic>? customFields,
    String? dateAdded,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      serial: serial ?? this.serial,
      status: status ?? this.status,
      assignee: assignee ?? this.assignee,
      customFields: customFields ?? this.customFields,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }
}
