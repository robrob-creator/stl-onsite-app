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
  final TransactionReference? reference;
  final String status;
  final String type;
  final UserData? user;
  final String? drawTime;
  final String? drawTimeId;

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
    this.reference,
    required this.status,
    required this.type,
    this.user,
    this.drawTime,
    this.drawTimeId,
  });

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    String? drawTime,
    String? drawTimeId,
  }) {
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
      reference: json['reference'] is Map<String, dynamic>
          ? TransactionReference.fromJson(
              json['reference'] as Map<String, dynamic>,
            )
          : null,
      status: json['status'] as String,
      type: json['type'] as String,
      // Accept either 'user' or 'agent' payload keys for backward/forward compatibility
      user: (json['user'] is Map<String, dynamic>)
          ? UserData.fromJson(json['user'] as Map<String, dynamic>)
          : (json['agent'] is Map<String, dynamic>)
              ? UserData.fromJson(json['agent'] as Map<String, dynamic>)
              : null,
      drawTime: drawTime,
      drawTimeId: drawTimeId,
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
      'reference': reference?.toJson(),
      'status': status,
      'type': type,
      'user': user?.toJson(),
      'draw_time': drawTime,
      'draw_time_id': drawTimeId,
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

class TransactionGroup {
  final String drawTimeId;
  final String drawTime;
  final List<Transaction> transactions;

  TransactionGroup({
    required this.drawTimeId,
    required this.drawTime,
    required this.transactions,
  });

  double get totalAmount => transactions.fold(0.0, (sum, t) => sum + t.amount);

  int get count => transactions.length;

  String get overallStatus {
    // Treat 'printed' as completed (printed tickets imply transaction completed
    // from a printing perspective). Consider any of these as completed-like.
    final completedLike = (String s) => s.toLowerCase() == 'completed' || s.toLowerCase() == 'printed';
    if (transactions.any((t) => t.status.toLowerCase() == 'failed')) return 'failed';
    return 'completed';
  }

  String get createdAt =>
      transactions.isNotEmpty ? transactions.first.createdAt : '';
}

class TicketCustomer {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String role;

  TicketCustomer({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
  });

  factory TicketCustomer.fromJson(Map<String, dynamic> json) {
    return TicketCustomer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }
}

class Ticket {
  final String id;
  final String batchId;
  final String accountNumber;
  final String createdAt;
  final String? deletedAt;
  final TicketCustomer? customer;
  final String paymentMethod;
  final String status;
  final String ticketNo;
  final double totalBetAmount;
  final int totalBets;
  final double winningPayout;
  final String? drawTime;
  final String? drawTimeId;

  Ticket({
    required this.id,
    required this.batchId,
    required this.accountNumber,
    required this.createdAt,
    this.deletedAt,
    this.customer,
    required this.paymentMethod,
    required this.status,
    required this.ticketNo,
    required this.totalBetAmount,
    required this.totalBets,
    required this.winningPayout,
    this.drawTime,
    this.drawTimeId,
  });

  factory Ticket.fromJson(
    Map<String, dynamic> json, {
    String? drawTime,
    String? drawTimeId,
  }) {
    return Ticket(
      id: json['id'] as String? ?? '',
      batchId: json['batch_id'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      deletedAt: json['deleted_at'] as String?,
      // Support either 'customer' or 'agent' keys depending on API response
      customer: (json['customer'] is Map<String, dynamic>)
          ? TicketCustomer.fromJson(json['customer'] as Map<String, dynamic>)
          : (json['agent'] is Map<String, dynamic>)
              ? TicketCustomer.fromJson(json['agent'] as Map<String, dynamic>)
              : null,
      paymentMethod: json['payment_method'] as String? ?? '',
      status: json['status'] as String? ?? '',
      ticketNo: json['ticket_no'] as String? ?? '',
      totalBetAmount: (json['total_bet_amount'] as num?)?.toDouble() ?? 0.0,
      totalBets: (json['total_bets'] as num?)?.toInt() ?? 0,
      winningPayout: (json['winning_payout'] as num?)?.toDouble() ?? 0.0,
      drawTime: drawTime,
      drawTimeId: drawTimeId,
    );
  }
}

class TicketGroup {
  final String drawTimeId;
  final String drawTime;
  final List<Ticket> tickets;

  TicketGroup({
    required this.drawTimeId,
    required this.drawTime,
    required this.tickets,
  });

  double get totalAmount =>
      tickets.fold(0.0, (sum, t) => sum + t.totalBetAmount);

  int get count => tickets.length;

  String get overallStatus {
    final completedLike = (String s) => s.toLowerCase() == 'completed' || s.toLowerCase() == 'printed';
    if (tickets.any((t) => t.status.toLowerCase() == 'failed')) return 'failed';
    return 'completed';
  }

  String get createdAt => tickets.isNotEmpty ? tickets.first.createdAt : '';
}

class TicketBet {
  final String id;
  final String drawId;
  final String gameId;
  final String gameName; // optional readable name when provided
  final double straightBetAmount;
  final double rambleBetAmount;
  final double totalBetAmount;
  final String status;
  final String ticketNo;
  final String drawDate;
  final List<String> digits;
  final double estPayout;
  final String createdAt;

  TicketBet({
    required this.id,
    required this.drawId,
    required this.gameId,
    required this.gameName,
    required this.straightBetAmount,
    required this.rambleBetAmount,
    required this.totalBetAmount,
    required this.status,
    required this.ticketNo,
    required this.drawDate,
    required this.digits,
    required this.estPayout,
    required this.createdAt,
  });

  String get betType => straightBetAmount > 0 ? 'Target' : 'Rambol';

  factory TicketBet.fromJson(Map<String, dynamic> json) {
    return TicketBet(
      id: json['id'] as String? ?? '',
      drawId: json['draw_id'] as String? ?? '',
      gameId: json['game_id'] as String? ?? '',
      gameName: json['game_name'] as String? ?? '',
      straightBetAmount:
          (json['straight_bet_amount'] as num?)?.toDouble() ?? 0.0,
      rambleBetAmount: (json['ramble_bet_amount'] as num?)?.toDouble() ?? 0.0,
      totalBetAmount: (json['total_bet_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? '',
      ticketNo: json['ticket_no'] as String? ?? '',
      drawDate: json['draw_date'] as String? ?? '',
      digits:
          (json['digits'] as List?)?.map((e) => e.toString()).toList() ?? [],
      estPayout: (json['est_payout'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class TransactionBet {
  final String id;
  final String gameName;
  final List<String> digits;
  final double straightBetAmount;
  final double rambleBetAmount;
  final double totalBetAmount;
  final String status;
  final String ticketNo;

  TransactionBet({
    required this.id,
    required this.gameName,
    required this.digits,
    required this.straightBetAmount,
    required this.rambleBetAmount,
    required this.totalBetAmount,
    required this.status,
    required this.ticketNo,
  });

  String get betType => straightBetAmount > 0 ? 'Target' : 'Rambol';

  factory TransactionBet.fromJson(Map<String, dynamic> json) {
    return TransactionBet(
      id: json['id'] as String,
      gameName: json['game_name'] as String? ?? '',
      digits:
          (json['digits'] as List?)?.map((e) => e.toString()).toList() ?? [],
      straightBetAmount: (json['straight_bet_amount'] as num?)?.toDouble() ?? 0,
      rambleBetAmount: (json['ramble_bet_amount'] as num?)?.toDouble() ?? 0,
      totalBetAmount: (json['total_bet_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
      ticketNo: json['ticket_no'] as String? ?? '',
    );
  }
}
