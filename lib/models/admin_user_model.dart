class AdminUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String? avatarUrl;
  final DateTime createdAt;
  final String? gender;
  final DateTime? dateOfBirth;

  AdminUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
    this.gender,
    this.dateOfBirth,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      avatarUrl: json['avatar_url'],
      createdAt: DateTime.parse(json['created_at']),
      gender: json['gender'],
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'])
          : null,
    );
  }
}
