class Bet {
  final String? id;
  final String? agentId;
  final String drawId;
  final String gameId;
  final String number;
  final double straightBetAmount;
  final double rambleBetAmount;
  final double totalBetAmount;
  final String status;
  final String? batchId;
  final String? tempId;
  final String? estPayout;
  final String? customerId;
  final String? ticketNo;
  final String? drawDate;
  final List<String>? digits;
  final String? ipAddress;
  final String? areaId;
  final String? makerId;
  final String? drawResult;
  final String? clusterId;
  final double? winningPayout;
  final String paymentMethod;
  final String? accountNumber;
  final String? userId;
  final String? ticketId;
  final double? amount;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  Bet({
    this.id,
    this.agentId,
    required this.drawId,
    required this.gameId,
    required this.number,
    this.straightBetAmount = 0.0,
    this.rambleBetAmount = 0.0,
    required this.totalBetAmount,
    this.status = 'pending',
    this.batchId,
    this.tempId,
    this.estPayout,
    this.customerId,
    this.ticketNo,
    this.drawDate,
    this.digits,
    this.ipAddress,
    this.areaId,
    this.makerId,
    this.drawResult,
    this.clusterId,
    this.winningPayout,
    required this.paymentMethod,
    this.accountNumber,
    this.userId,
    this.ticketId,
    this.amount,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Bet.fromJson(Map<String, dynamic> json) {
    return Bet(
      id: json['id'],
      agentId: json['agent_id'],
      drawId: json['draw_id'] ?? '',
      gameId: json['game_id'] ?? '',
      number: json['number'] ?? '',
      straightBetAmount: (json['straight_bet_amount'] ?? 0).toDouble(),
      rambleBetAmount: (json['ramble_bet_amount'] ?? 0).toDouble(),
      totalBetAmount: (json['total_bet_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      batchId: json['batch_id'],
      tempId: json['temp_id'],
      estPayout: json['est_payout']?.toString(),
      customerId: json['customer_id'],
      ticketNo: json['ticket_no'],
      drawDate: json['draw_date'],
      digits: json['digits'] != null ? List<String>.from(json['digits']) : null,
      ipAddress: json['ip_address'],
      areaId: json['area_id'],
      makerId: json['maker_id'],
      drawResult: json['draw_result'],
      clusterId: json['cluster_id'],
      winningPayout: json['winning_payout']?.toDouble(),
      paymentMethod: json['payment_method'] ?? 'cash',
      accountNumber: json['account_number'],
      userId: json['user_id'],
      ticketId: json['ticket_id'],
      amount: json['amount']?.toDouble(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      deletedAt: json['deleted_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'agent_id': agentId,
      'draw_id': drawId,
      'game_id': gameId,
      'number': number,
      'straight_bet_amount': straightBetAmount,
      'ramble_bet_amount': rambleBetAmount,
      'total_bet_amount': totalBetAmount,
      'status': status,
      'batch_id': batchId,
      'temp_id': tempId,
      'est_payout': estPayout,
      'customer_id': customerId,
      'ticket_no': ticketNo,
      'draw_date': drawDate,
      'digits': digits,
      'ip_address': ipAddress,
      'area_id': areaId,
      'maker_id': makerId,
      'draw_result': drawResult,
      'cluster_id': clusterId,
      'winning_payout': winningPayout,
      'payment_method': paymentMethod,
      'account_number': accountNumber,
      'user_id': userId,
      'ticket_id': ticketId,
      'amount': amount,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
    };
  }
}
