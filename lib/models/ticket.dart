class Ticket {
  final String id;
  final String ticketNo;
  final String batchId;
  final List<BetData> bets;
  final String status;
  final CustomerData customer;
  final ClusterData cluster;
  final String createdAt;
  final String? paymentMethod;
  final String? accountNumber;
  final String? deletedAt;
  final double winningpayout;

  Ticket({
    required this.id,
    required this.ticketNo,
    required this.batchId,
    required this.bets,
    required this.status,
    required this.customer,
    required this.cluster,
    required this.createdAt,
    this.paymentMethod,
    this.accountNumber,
    this.deletedAt,
    this.winningpayout = 0.0,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as String,
      ticketNo: json['ticket_no'] as String,
      batchId: json['batch_id'] as String,
      bets:
          (json['bets'] as List?)
              ?.map((bet) => BetData.fromJson(bet as Map<String, dynamic>))
              .toList() ??
          [],
      status: json['status'] as String,
      customer: CustomerData.fromJson(json['customer'] as Map<String, dynamic>),
      cluster: ClusterData.fromJson(json['cluster'] as Map<String, dynamic>),
      createdAt: json['created_at'] as String,
      paymentMethod: json['payment_method'] as String?,
      accountNumber: json['account_number'] as String?,
      deletedAt: json['deleted_at'] as String?,
      winningpayout: (json['winning_payout'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_no': ticketNo,
      'batch_id': batchId,
      'bets': bets.map((b) => b.toJson()).toList(),
      'status': status,
      'customer': customer.toJson(),
      'cluster': cluster.toJson(),
      'created_at': createdAt,
      'payment_method': paymentMethod,
      'account_number': accountNumber,
      'price_payoff': winningpayout,
      'deleted_at': deletedAt,
    };
  }
}

class CustomerData {
  final String id;
  final String name;
  final String email;
  final String role;

  CustomerData({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory CustomerData.fromJson(Map<String, dynamic> json) {
    return CustomerData(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'role': role};
  }
}

class ClusterData {
  final String id;
  final String name;

  ClusterData({required this.id, required this.name});

  factory ClusterData.fromJson(Map<String, dynamic> json) {
    return ClusterData(id: json['id'] as String, name: json['name'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}

class BetData {
  final String id;
  final String gameId;
  final String? number;
  final List<String> digits;
  final double straightBetAmount;
  final double rambleBetAmount;
  final double totalBetAmount;
  final String status;
  final double estPayout;
  final String? ticketNo;
  final String createdAt;

  BetData({
    required this.id,
    required this.gameId,
    this.number,
    required this.digits,
    required this.straightBetAmount,
    required this.rambleBetAmount,
    required this.totalBetAmount,
    required this.status,
    required this.estPayout,
    this.ticketNo,
    required this.createdAt,
  });

  factory BetData.fromJson(Map<String, dynamic> json) {
    return BetData(
      id: json['id'] as String,
      gameId: json['game_id'] as String,
      number: json['number'] as String?,
      digits:
          (json['digits'] as List?)?.map((d) => d.toString()).toList() ?? [],
      straightBetAmount:
          (json['straight_bet_amount'] as num?)?.toDouble() ?? 0.0,
      rambleBetAmount: (json['ramble_bet_amount'] as num?)?.toDouble() ?? 0.0,
      totalBetAmount: (json['total_bet_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String,
      estPayout: (json['est_payout'] as num?)?.toDouble() ?? 0.0,
      ticketNo: json['ticket_no'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game_id': gameId,
      'number': number,
      'digits': digits,
      'straight_bet_amount': straightBetAmount,
      'ramble_bet_amount': rambleBetAmount,
      'total_bet_amount': totalBetAmount,
      'status': status,
      'est_payout': estPayout,
      'ticket_no': ticketNo,
      'created_at': createdAt,
    };
  }
}
