/// Personnel model — represents a real person who is assigned physical assets.
/// NOT an app user/login account. Fully separate from the User model.
class Personnel {
  final String id;
  final String fullName;
  final String department;
  final String contactEmail;
  final String? notes;
  final int workstationsCount;
  final int peripheralsCount;
  final int totalAssetsCount;
  final List<Map<String, dynamic>> workstations;
  final List<Map<String, dynamic>> peripherals;

  Personnel({
    required this.id,
    required this.fullName,
    this.department = '',
    this.contactEmail = '',
    this.notes,
    this.workstationsCount = 0,
    this.peripheralsCount = 0,
    this.totalAssetsCount = 0,
    this.workstations = const [],
    this.peripherals = const [],
  });

  factory Personnel.fromJson(Map<String, dynamic> json) {
    final wsList = json['workstations'] is List
        ? (json['workstations'] as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    return Personnel(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      contactEmail: json['contactEmail']?.toString() ?? '',
      notes: json['notes']?.toString(),
      workstationsCount: json['workstationsCount'] ?? wsList.length,
      peripheralsCount: json['peripheralsCount'] ?? 0,
      totalAssetsCount: json['totalAssetsCount'] ?? wsList.length,
      workstations: wsList,
      peripherals: json['peripherals'] is List
          ? (json['peripherals'] as List).cast<Map<String, dynamic>>()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'department': department,
        'contactEmail': contactEmail,
        'notes': notes,
      };
}
