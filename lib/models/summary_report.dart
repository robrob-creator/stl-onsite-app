class SummaryReportModel {
  final String date;
  final List<GameSummary> games;

  SummaryReportModel({required this.date, required this.games});

  factory SummaryReportModel.fromJson(Map<String, dynamic> json) {
    return SummaryReportModel(
      date: json['date'] ?? '',
      games: (json['games'] as List? ?? [])
          .map((g) => GameSummary.fromJson(g))
          .toList(),
    );
  }
}

class GameSummary {
  final String gameId;
  final String gameName;
  final double totalBets;
  final double hits;
  final double net;
  final List<DrawTimeSummary> drawTimes;

  GameSummary({
    required this.gameId,
    required this.gameName,
    required this.totalBets,
    required this.hits,
    required this.net,
    required this.drawTimes,
  });

  factory GameSummary.fromJson(Map<String, dynamic> json) {
    return GameSummary(
      gameId: json['game_id'] ?? '',
      gameName: json['game_name'] ?? '',
      totalBets: (json['total_bets'] ?? 0).toDouble(),
      hits: (json['hits'] ?? 0).toDouble(),
      net: (json['net'] ?? 0).toDouble(),
      drawTimes: (json['draw_times'] as List? ?? [])
          .map((d) => DrawTimeSummary.fromJson(d))
          .toList(),
    );
  }
}

class DrawTimeSummary {
  final String drawTimeId;
  final String drawTime;
  final int betCount;
  final double totalBets;
  final double hits;
  final double net;

  DrawTimeSummary({
    required this.drawTimeId,
    required this.drawTime,
    required this.betCount,
    required this.totalBets,
    required this.hits,
    required this.net,
  });

  factory DrawTimeSummary.fromJson(Map<String, dynamic> json) {
    return DrawTimeSummary(
      drawTimeId: json['draw_time_id'] ?? '',
      drawTime: json['draw_time'] ?? '',
      betCount: json['bet_count'] ?? 0,
      totalBets: (json['total_bets'] ?? 0).toDouble(),
      hits: (json['hits'] ?? 0).toDouble(),
      net: (json['net'] ?? 0).toDouble(),
    );
  }
}
