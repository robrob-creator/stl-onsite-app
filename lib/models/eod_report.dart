class EodBreakdownItem {
  final String gameId;
  final String gameName;
  final int betCount;
  final double grossSales;
  final double hits;
  final double net;

  EodBreakdownItem({
    required this.gameId,
    required this.gameName,
    required this.betCount,
    required this.grossSales,
    required this.hits,
    required this.net,
  });

  factory EodBreakdownItem.fromJson(Map<String, dynamic> json) {
    return EodBreakdownItem(
      gameId: json['game_id'] ?? '',
      gameName: json['game_name'] ?? '',
      betCount: (json['bet_count'] ?? 0).toInt(),
      grossSales: (json['gross_sales'] ?? 0).toDouble(),
      hits: (json['hits'] ?? 0).toDouble(),
      net: (json['net'] ?? 0).toDouble(),
    );
  }
}

class EodReportModel {
  final String location;
  final String tellerId;
  final String tellerName;
  final String reportDate;
  final double grossSales;
  final double lessCommission;
  final double hits;
  final double totalNet;
  final double forCollection;
  final int totalBets;
  final List<EodBreakdownItem> breakdown;

  EodReportModel({
    required this.location,
    required this.tellerId,
    required this.tellerName,
    required this.reportDate,
    required this.grossSales,
    required this.lessCommission,
    required this.hits,
    required this.totalNet,
    required this.forCollection,
    required this.totalBets,
    required this.breakdown,
  });

  factory EodReportModel.fromJson(Map<String, dynamic> json) {
    return EodReportModel(
      location: json['location'] ?? '',
      tellerId: json['teller_id'] ?? '',
      tellerName: json['teller_name'] ?? '',
      reportDate: json['report_date'] ?? '',
      grossSales: (json['gross_sales'] ?? 0).toDouble(),
      lessCommission: (json['less_commission'] ?? 0).toDouble(),
      hits: (json['hits'] ?? 0).toDouble(),
      totalNet: (json['total_net'] ?? 0).toDouble(),
      forCollection: (json['for_collection'] ?? 0).toDouble(),
      totalBets: (json['total_bets'] ?? 0).toInt(),
      breakdown: (json['breakdown'] as List? ?? [])
          .map((item) => EodBreakdownItem.fromJson(item))
          .toList(),
    );
  }
}
