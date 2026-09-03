/// One row on the agent's Collection page. Represents a single draw slot the
/// agent had bets in — the slot may or may not yet have a collection record.
class Collection {
  final String drawResultId;
  final String drawDate;
  final String drawTime;
  final double grossAmount;
  final double hitsAmount;
  final double commissionAmount;
  final double netAmount;
  final double paidAmount;
  final double carryoverAmount;
  final bool isTapada;
  final String tapadaStatus;
  final String status;
  final String remittanceStatus;
  final double remittedAmount;
  final double agentOutstandingAmount;
  final double rawBalance;
  final String? collectionId;
  final bool isCollected;

  Collection({
    required this.drawResultId,
    required this.drawDate,
    required this.drawTime,
    required this.grossAmount,
    required this.hitsAmount,
    required this.commissionAmount,
    required this.netAmount,
    required this.paidAmount,
    required this.carryoverAmount,
    required this.isTapada,
    required this.tapadaStatus,
    required this.status,
    required this.remittanceStatus,
    required this.remittedAmount,
    required this.agentOutstandingAmount,
    required this.rawBalance,
    required this.isCollected,
    this.collectionId,
  });

  /// Human-facing label rendered inside the status badge on the row.
  String get statusLabel {
    if (netAmount < 0 && tapadaStatus != 'completed') return 'Unsettled';
    if (netAmount < 0) return 'Settled';
    if (isFullySettled) {
      final remStatus = remittanceStatus.toLowerCase();
      if (remStatus == 'paid' || remStatus == 'remitted' || remStatus == 'approved') {
        return 'Remitted';
      }
      return 'Collected';
    }
    if (agentOutstandingAmount > 0.005) return 'Partial';
    if (status == 'paid') return 'Pending Remittance';
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Collected';
      case 'partial':
        return 'Partial';
      case 'tapada':
        return 'Settled';
      case 'uncollected':
        return 'Uncollected';
      default:
        return status.isEmpty
            ? 'Uncollected'
            : status[0].toUpperCase() + status.substring(1);
    }
  }

  bool get isFullySettled {
    if (isTapada || netAmount <= 0) return true;
    if (agentOutstandingAmount >= 0) {
      return agentOutstandingAmount <= 0.005;
    }
    final remittance = remittanceStatus.toLowerCase();
    final approved = remittance == 'remitted' ||
        remittance == 'paid' ||
        remittance == 'settle' ||
        remittance == 'settled' ||
        remittance == 'approved';
    return approved &&
        (remittance != 'partial' || remittedAmount >= netAmount - 0.005);
  }

  factory Collection.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) => (v is num) ? v.toDouble() : 0.0;
    final rawCollectionId = json['collection_id'] as String?;
    return Collection(
      drawResultId: json['draw_result_id'] as String? ?? '',
      drawDate: json['draw_date'] as String? ?? '',
      drawTime: json['draw_time'] as String? ?? '',
      grossAmount: asDouble(json['gross_amount']),
      hitsAmount: asDouble(json['hits_amount']),
      commissionAmount: asDouble(json['commission_amount']),
      netAmount: asDouble(json['net_amount']),
      paidAmount: asDouble(json['paid_amount']),
      carryoverAmount: asDouble(json['carryover_amount']),
      isTapada: json['is_tapada'] as bool? ?? false,
      tapadaStatus: (json['tapada_status'] as String? ?? '').toLowerCase(),
      status: (json['status'] as String? ?? '').toLowerCase(),
      remittanceStatus: json['remittance_status'] as String? ?? '',
      remittedAmount: asDouble(json['remit_approved_sum']),
      agentOutstandingAmount: asDouble(json['agent_outstanding_amount']),
      rawBalance: asDouble(json['raw_balance']),
      collectionId:
          (rawCollectionId == null || rawCollectionId.isEmpty) ? null : rawCollectionId,
      isCollected: json['is_collected'] as bool? ?? false,
    );
  }
}
