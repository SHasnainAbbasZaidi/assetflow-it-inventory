class User {
  final String id;
  final String name;
  final String department;
  final String email;
  final String password;
  final bool isAdmin;

  User({
    required this.id,
    required this.name,
    required this.department,
    required this.email,
    required this.password,
    this.isAdmin = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'department': department,
      'email': email,
      'password': password,
      'isAdmin': isAdmin,
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
    );
  }
}
