class SoldOutRow {
  final String id;
  final String gameId;
  final String? drawTimeId;
  final dynamic betNumbers;
  final DateTime? dateStarted;
  final DateTime? dateEnded;
  final double? maxAmount;
  final bool isActive;
  final String? type;
  final String? mode;

  SoldOutRow({
    required this.id,
    required this.gameId,
    this.drawTimeId,
    this.betNumbers,
    this.dateStarted,
    this.dateEnded,
    this.maxAmount,
    required this.isActive,
    this.type,
    this.mode,
  });

  factory SoldOutRow.fromJson(Map<String, dynamic> json) {
    return SoldOutRow(
      id: json['id'] as String,
      gameId: json['game_id'] as String,
      drawTimeId: json['draw_time_id'] as String?,
      betNumbers: json['bet_numbers'],
      dateStarted: json['date_started'] != null
          ? DateTime.tryParse(json['date_started'] as String)
          : null,
      dateEnded: json['date_ended'] != null
          ? DateTime.tryParse(json['date_ended'] as String)
          : null,
      maxAmount: (json['max_amount'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      type: json['type'] as String?,
      mode: json['mode'] as String?,
    );
  }
}
