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
    // Partial admin remittance: admin approved only part of what was collected.
    // Must be checked BEFORE isFullySettled so it never resolves to 'Remitted'.
    // Gated on a genuine remaining gap (agentOutstandingAmount) — the backend
    // stamps remittance_status='partial' the instant a remittance is merely
    // *submitted* (before admin decides) or leaves it stuck there through a
    // resolved re-collection chain, so the raw string alone doesn't mean
    // there's still money outstanding.
    if (remittanceStatus.toLowerCase() == 'partial' &&
        agentOutstandingAmount > 0.005) {
      return 'Partial Remittance';
    }
    if (isFullySettled) {
      final remStatus = remittanceStatus.toLowerCase();
      if (remStatus == 'settle' || remStatus == 'settled') return 'Settled';
      // agentOutstandingAmount <= 0.005 is what actually made isFullySettled
      // true here (agentOutstandingAmount is void-aware and nets against
      // admin-approved sums) — that already means admin has approved enough
      // to cover the full net amount, i.e. it genuinely has been remitted,
      // regardless of what the raw remittance_status string still says (it
      // can be stuck at 'partial' or 'unremitted' even once a re-collection
      // chain or a later full approval has actually resolved it).
      return 'Remitted';
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
    // agentOutstandingAmount is the authoritative, void-aware figure for
    // whether there's still a genuine gap — check it before trusting the raw
    // remittance_status string, which can read 'partial' even once a
    // re-collection chain has fully resolved it, or the instant a remittance
    // is merely submitted and still awaiting admin's decision.
    if (agentOutstandingAmount >= 0) {
      return agentOutstandingAmount <= 0.005;
    }
    // Partial admin remittance → not fully settled regardless of outstanding.
    if (remittanceStatus.toLowerCase() == 'partial') return false;
    final remittance = remittanceStatus.toLowerCase();
    final approved = remittance == 'remitted' ||
        remittance == 'paid' ||
        remittance == 'settle' ||
        remittance == 'settled' ||
        remittance == 'approved';
    return approved;
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
