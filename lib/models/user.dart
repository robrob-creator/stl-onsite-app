class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;
  final String phoneNumber;
  final double balance;
  final bool isActive;
  final bool isBlocked;
  final double winningsAmount;
  final double shareAmount;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.phoneNumber,
    required this.balance,
    required this.isActive,
    required this.isBlocked,
    required this.winningsAmount,
    required this.shareAmount,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      phoneNumber: json['phone_number'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      isActive: json['is_active'] ?? false,
      isBlocked: json['is_blocked'] ?? false,
      winningsAmount: (json['winnings_amount'] ?? 0).toDouble(),
      shareAmount: (json['share_amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'phone_number': phoneNumber,
      'balance': balance,
      'is_active': isActive,
      'is_blocked': isBlocked,
      'winnings_amount': winningsAmount,
      'share_amount': shareAmount,
    };
  }
}
