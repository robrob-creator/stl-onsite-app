import 'bet.dart';

class Ticket {
  final String? id;
  final String? ticketNo;
  final String? batchId;
  final String? clusterId;
  final String? customerId;
  final String? drawId;
  final String? paymentMethod;
  final String? accountNumber;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  Ticket({
    this.id,
    this.ticketNo,
    this.batchId,
    this.clusterId,
    this.customerId,
    this.drawId,
    this.paymentMethod,
    this.accountNumber,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as String?,
      ticketNo: json['ticket_no'] as String?,
      batchId: json['batch_id'] as String?,
      clusterId: json['cluster_id'] as String?,
      customerId: json['customer_id'] as String?,
      drawId: json['draw_id'] as String?,
      paymentMethod: json['payment_method'] as String?,
      accountNumber: json['account_number'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      deletedAt: json['deleted_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_no': ticketNo,
      'batch_id': batchId,
      'cluster_id': clusterId,
      'customer_id': customerId,
      'draw_id': drawId,
      'payment_method': paymentMethod,
      'account_number': accountNumber,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }
}

class Claim {
  final String? id;
  final String? ticketId;
  final String? betId;
  final String? customerId;
  final String? winningCombination;
  final double winningAmount;
  final String? drawTimeId;
  final String? drawDate;
  final double amount;
  final String? status;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final Bet? bet;
  final Ticket? ticket;

  Claim({
    this.id,
    this.ticketId,
    this.betId,
    this.customerId,
    this.winningCombination,
    this.winningAmount = 0.0,
    this.drawTimeId,
    this.drawDate,
    this.amount = 0.0,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.bet,
    this.ticket,
  });

  factory Claim.fromJson(Map<String, dynamic> json) {
    return Claim(
      id: json['id'] as String?,
      ticketId: json['ticket_id'] as String?,
      betId: json['bet_id'] as String?,
      customerId: json['customer_id'] as String?,
      winningCombination: json['winning_combination'] as String?,
      winningAmount: (json['winning_amount'] as num?)?.toDouble() ?? 0.0,
      drawTimeId: json['draw_time_id'] as String?,
      drawDate: json['draw_date'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      deletedAt: json['deleted_at'] as String?,
      bet: json['bet'] != null ? Bet.fromJson(json['bet']) : null,
      ticket: json['ticket'] != null ? Ticket.fromJson(json['ticket']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'bet_id': betId,
      'customer_id': customerId,
      'winning_combination': winningCombination,
      'winning_amount': winningAmount,
      'draw_time_id': drawTimeId,
      'draw_date': drawDate,
      'amount': amount,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
      'bet': bet?.toJson(),
      'ticket': ticket?.toJson(),
    };
  }
}
