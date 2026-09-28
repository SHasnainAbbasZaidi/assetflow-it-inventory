class User {
  final String id;
  final String name;
  final String department;
  final String email;
  final String password;
  final bool isAdmin;
  final Map<String, bool>? customPermissions;
  final Map<String, bool>? permissions;
  bool can(String key) =>
      isAdmin ||
      (permissions?[key] ??
          customPermissions?[key] ??
          (['view', 'export'].contains(key) ||
              department == 'EDITOR' && ['add', 'edit'].contains(key)));
  static const accessLabels = {
    'view': 'View inventory and personnel',
    'add': 'Add items and personnel',
    'edit': 'Edit items, assignments and status',
    'delete': 'Delete personnel records',
    'export': 'Export Excel',
    'reports': 'View and generate reports'
  };
  factory User.fromApi(Map<String, dynamic> value) => User(
      id: value['email'],
      name: value['fullName'] ?? '',
      department: value['role'] ?? 'VIEWER',
      email: value['email'],
      password: '',
      isAdmin: value['role'] == 'ADMIN',
      permissions: value['permissions'] == null
          ? null
          : Map<String, bool>.from(value['permissions']),
      customPermissions: value['customPermissions'] == null
          ? null
          : Map<String, bool>.from(value['customPermissions']));

  User({
    required this.id,
    required this.name,
    required this.department,
    required this.email,
    required this.password,
    this.isAdmin = false,
    this.permissions,
    this.customPermissions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'department': department,
      'email': email,
      'password': password,
      'isAdmin': isAdmin,
      'permissions': permissions,
      'customPermissions': customPermissions,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      department: map['department'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
      permissions: map['permissions'] == null
          ? null
          : Map<String, bool>.from(map['permissions']),
      customPermissions: map['customPermissions'] == null
          ? null
          : Map<String, bool>.from(map['customPermissions']),
    );
  }

  User copyWith({
    String? id,
    String? name,
    String? department,
    String? email,
    String? password,
    bool? isAdmin,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      department: department ?? this.department,
      email: email ?? this.email,
      password: password ?? this.password,
      isAdmin: isAdmin ?? this.isAdmin,
      permissions: permissions,
      customPermissions: customPermissions,
    );
  }
}
