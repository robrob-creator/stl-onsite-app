class Ticket {
  final String? id;
  final String? ticketNo;
  final String? batchId;
  final List<BetData>? betIds;
  final String? status;
  final CustomerData? customer;
  final ClusterData? cluster;
  final String? createdAt;
  final String? paymentMethod;
  final String? accountNumber;
  final String? deletedAt;
  final double? winningPayout;

  Ticket({
    this.id,
    this.ticketNo,
    this.batchId,
    this.betIds,
    this.status,
    this.customer,
    this.cluster,
    this.createdAt,
    this.paymentMethod,
    this.accountNumber,
    this.deletedAt,
    this.winningPayout,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as String?,
      ticketNo: json['ticket_no'] as String?,
      batchId: json['batch_id'] as String?,
      betIds: (json['bet_ids'] as List?)
          ?.map((bet) => BetData.fromJson(bet as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String? ?? 'unknown',
      customer: json['customer'] != null
          ? CustomerData.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      cluster: json['cluster'] != null
          ? ClusterData.fromJson(json['cluster'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] as String?,
      paymentMethod: json['payment_method'] as String?,
      accountNumber: json['account_number'] as String?,
      deletedAt: json['deleted_at'] as String?,
      winningPayout: json['winning_payout']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_no': ticketNo,
      'batch_id': batchId,
      'bet_ids': betIds?.map((b) => b.toJson()).toList(),
      'status': status,
      'customer': customer?.toJson(),
      'cluster': cluster?.toJson(),
      'created_at': createdAt,
      'payment_method': paymentMethod,
      'account_number': accountNumber,
      'deleted_at': deletedAt,
      'winning_payout': winningPayout,
    };
  }
}

class CustomerData {
  final String? id;
  final String? name;
  final String? email;
  final String? role;

  CustomerData({this.id, this.name, this.email, this.role});

  factory CustomerData.fromJson(Map<String, dynamic> json) {
    return CustomerData(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'role': role};
  }
}

class ClusterData {
  final String? id;
  final String? name;

  ClusterData({this.id, this.name});

  factory ClusterData.fromJson(Map<String, dynamic> json) {
    return ClusterData(
      id: json['id'] as String?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}

class BetData {
  final String? id;
  final String? gameId;
  final String? number;
  final List<String>? digits;
  final double? straightBetAmount;
  final double? rambleBetAmount;
  final double? totalBetAmount;
  final String? status;
  final double? estPayout;
  final String? ticketNo;
  final String? createdAt;

  BetData({
    this.id,
    this.gameId,
    this.number,
    this.digits,
    this.straightBetAmount,
    this.rambleBetAmount,
    this.totalBetAmount,
    this.status,
    this.estPayout,
    this.ticketNo,
    this.createdAt,
  });

  factory BetData.fromJson(Map<String, dynamic> json) {
    // Handle digits as either a string (e.g. "{31,14}") or a List
    List<String>? parsedDigits;
    if (json['digits'] != null) {
      if (json['digits'] is String) {
        String digitsStr = (json['digits'] as String)
            .replaceAll('{', '')
            .replaceAll('}', '')
            .trim();
        if (digitsStr.isNotEmpty) {
          parsedDigits = digitsStr.split(',').map((d) => d.trim()).toList();
        } else {
          parsedDigits = <String>[];
        }
      } else if (json['digits'] is List) {
        parsedDigits = (json['digits'] as List)
            .map((d) => d.toString())
            .toList();
      }
    }
    return BetData(
      id: json['id'] as String?,
      gameId: json['game_id'] as String?,
      number: json['number'] as String?,
      digits: parsedDigits,
      straightBetAmount: (json['straight_bet_amount'] as num?)?.toDouble(),
      rambleBetAmount: (json['ramble_bet_amount'] as num?)?.toDouble(),
      totalBetAmount: (json['total_bet_amount'] as num?)?.toDouble(),
      status: json['status'] as String?,
      estPayout: (json['est_payout'] as num?)?.toDouble(),
      ticketNo: json['ticket_no'] as String?,
      createdAt: json['created_at'] as String?,
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
