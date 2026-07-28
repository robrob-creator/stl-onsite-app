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
  final String status;
  final String remittanceStatus;
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
    required this.status,
    required this.remittanceStatus,
    required this.isCollected,
    this.collectionId,
  });

  /// Human-facing label rendered inside the status badge on the row.
  String get statusLabel {
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
      status: (json['status'] as String? ?? '').toLowerCase(),
      remittanceStatus: json['remittance_status'] as String? ?? '',
      collectionId:
          (rawCollectionId == null || rawCollectionId.isEmpty) ? null : rawCollectionId,
      isCollected: json['is_collected'] as bool? ?? false,
    );
  }
}
