class User {
  final int? id;
  String name;
  final String email;
  String password;
  String phone;
  final String gender;
  final String? createdAt;
  final bool isActive; // New field for user status
  final bool isAdmin; // Add this field
  final bool isDefaultAdmin;

  User({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.gender,
    this.createdAt,
    this.isActive = true, // Default to active
    this.isAdmin = false, // Default to non-admin
    this.isDefaultAdmin = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'gender': gender,
      'created_at': createdAt,
      'is_active': isActive ? 1 : 0, // Convert bool to int for SQLite
      'is_admin': isAdmin ? 1 : 0, // Convert bool to int for SQLite
      'is_default_admin': isDefaultAdmin ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      password: map['password'],
      phone: map['phone'],
      gender: map['gender'],
      createdAt: map['created_at'],
      isActive:
          map['is_active'] == null
              ? true
              : map['is_active'] == 1, // Convert int to bool
      isAdmin: map['is_admin'] == null ? false : map['is_admin'] == 1, // Convert int to bool
      isDefaultAdmin: map['is_default_admin'] == null ? false : map['is_default_admin'] == 1,
    );
  }
}
