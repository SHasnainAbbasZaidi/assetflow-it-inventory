class ActivityLog {
  final String id;
  final String timestamp;
  final String user;
  final String action;
  final String assetId;
  final String details;

  ActivityLog({
    required this.id,
    required this.timestamp,
    required this.user,
    required this.action,
    required this.assetId,
    required this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp,
      'user': user,
      'action': action,
      'assetId': assetId,
      'details': details,
    };
  }

  factory ActivityLog.fromMap(Map<dynamic, dynamic> map) {
    return ActivityLog(
      id: map['id'] ?? '',
      timestamp: map['timestamp'] ?? '',
      user: map['user'] ?? 'Admin',
      action: map['action'] ?? '',
      assetId: map['assetId'] ?? '',
      details: map['details'] ?? '',
    );
  }
}
