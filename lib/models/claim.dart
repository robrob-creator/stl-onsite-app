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
    };
  }
}
