class Transaction {
  final String id;
  final int idx;
  final double amount;
  final double? balance;
  final String createdAt;
  final String? deletedAt;
  final String description;
  final String? accountName;
  final String? accountNumber;
  final String? bank;
  final String method;
  final TransactionReference reference;
  final String status;
  final String type;
  final UserData user;

  Transaction({
    required this.id,
    required this.idx,
    required this.amount,
    this.balance,
    required this.createdAt,
    this.deletedAt,
    required this.description,
    this.accountName,
    this.accountNumber,
    this.bank,
    required this.method,
    required this.reference,
    required this.status,
    required this.type,
    required this.user,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      idx: json['idx'] as int,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String,
      deletedAt: json['deleted_at'] as String?,
      description: json['description'] as String,
      accountName: json['account_name'] as String?,
      accountNumber: json['account_number'] as String?,
      bank: json['bank'] as String?,
      method: json['method'] as String,
      reference: TransactionReference.fromJson(
        json['reference'] as Map<String, dynamic>,
      ),
      status: json['status'] as String,
      type: json['type'] as String,
      user: UserData.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idx': idx,
      'amount': amount,
      'balance': balance,
      'created_at': createdAt,
      'deleted_at': deletedAt,
      'description': description,
      'account_name': accountName,
      'account_number': accountNumber,
      'bank': bank,
      'method': method,
      'reference': reference.toJson(),
      'status': status,
      'type': type,
      'user': user.toJson(),
    };
  }
}

class TransactionReference {
  final List<BetReference> bets;
  final int count;
  final String type;

  TransactionReference({
    required this.bets,
    required this.count,
    required this.type,
  });

  factory TransactionReference.fromJson(Map<String, dynamic> json) {
    return TransactionReference(
      bets:
          (json['bets'] as List?)
              ?.map((bet) => BetReference.fromJson(bet as Map<String, dynamic>))
              .toList() ??
          [],
      count: json['count'] as int,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bets': bets.map((b) => b.toJson()).toList(),
      'count': count,
      'type': type,
    };
  }
}

class BetReference {
  final String id;
  final String gameId;
  final String gameName;
  final String drawId;
  final String ticketNo;
  final String status;
  final double totalBetAmount;
  final String createdAt;
  final List<String> digits;

  BetReference({
    required this.id,
    required this.gameId,
    required this.gameName,
    required this.drawId,
    required this.ticketNo,
    required this.status,
    required this.totalBetAmount,
    required this.createdAt,
    required this.digits,
  });

  factory BetReference.fromJson(Map<String, dynamic> json) {
    return BetReference(
      id: json['id'] as String,
      gameId: json['game_id'] as String,
      gameName: json['game_name'] as String? ?? '',
      drawId: json['draw_id'] as String,
      ticketNo: json['ticket_no'] as String,
      status: json['status'] as String,
      totalBetAmount: (json['total_bet_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String,
      digits: json['digits'] != null ? List<String>.from(json['digits']) : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game_id': gameId,
      'game_name': gameName,
      'draw_id': drawId,
      'ticket_no': ticketNo,
      'status': status,
      'total_bet_amount': totalBetAmount,
      'created_at': createdAt,
      'digits': digits,
    };
  }
}

class UserData {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final bool isBlocked;

  UserData({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.isBlocked,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? false,
      isBlocked: json['is_blocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'is_active': isActive,
      'is_blocked': isBlocked,
    };
  }
}
