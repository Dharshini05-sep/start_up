class UserModel {
  final String firstName;
  final String lastName;
  final String email;
  final String accountType; // 'Doctor', 'Guardian', 'Admin'
  final String passwordHash;
  final String salt;
  final DateTime createdAt;

  const UserModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.accountType,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'accountType': accountType,
      'passwordHash': passwordHash,
      'salt': salt,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      accountType: json['accountType'] as String? ?? 'Doctor',
      passwordHash: json['passwordHash'] as String? ?? '',
      salt: json['salt'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? accountType,
    String? passwordHash,
    String? salt,
    DateTime? createdAt,
  }) {
    return UserModel(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      accountType: accountType ?? this.accountType,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
