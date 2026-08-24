import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../app_constants.dart';

class LatestResult {
  final String? id;
  final String? result;
  final int? winAmount;
  final String? drawDate;
  final String? createdAt;

  LatestResult({
    this.id,
    this.result,
    this.winAmount,
    this.drawDate,
    this.createdAt,
  });

  factory LatestResult.fromJson(Map<String, dynamic> json) {
    return LatestResult(
      id: json['id'] as String?,
      result: json['result'] as String?,
      winAmount: json['win_amount'] as int?,
      drawDate: json['draw_date'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

class BetSummary {
  final int totalBet;
  final int totalWon;
  final int winningBetsCount;
  final bool isAtRisk;

  BetSummary({
    required this.totalBet,
    required this.totalWon,
    required this.winningBetsCount,
    required this.isAtRisk,
  });

  factory BetSummary.fromJson(Map<String, dynamic> json) {
    return BetSummary(
      totalBet: (json['total_bet'] as num?)?.toInt() ?? 0,
      totalWon: (json['total_won'] as num?)?.toInt() ?? 0,
      winningBetsCount: (json['winning_bets_count'] as num?)?.toInt() ?? 0,
      isAtRisk: json['is_at_risk'] as bool? ?? false,
    );
  }
}

class DrawResult {
  final String? id;
  final String? drawTime;
  final int? cutoffMinutes;
  final bool? isActive;
  final LatestResult? latestResult;
  final BetSummary? betSummary;

  DrawResult({
    this.id,
    this.drawTime,
    this.cutoffMinutes,
    this.isActive,
    this.latestResult,
    this.betSummary,
  });

  factory DrawResult.fromJson(Map<String, dynamic> json) {
    final latestResultData = json['latest_result'];
    final betSummaryData = json['bet_summary'];
    return DrawResult(
      id: json['id'] as String?,
      drawTime: json['draw_time'] as String?,
      cutoffMinutes: json['cutoff_minutes'] as int?,
      isActive: json['is_active'] as bool?,
      latestResult: latestResultData != null
          ? LatestResult.fromJson(latestResultData as Map<String, dynamic>)
          : null,
      betSummary: betSummaryData != null
          ? BetSummary.fromJson(betSummaryData as Map<String, dynamic>)
          : null,
    );
  }
}

class DrawResultsResponse {
  final String? message;
  final String? gameId;
  final String? drawDate;
  final List<DrawResult> drawTimes;
  final int? totalCount;

  DrawResultsResponse({
    this.message,
    this.gameId,
    this.drawDate,
    required this.drawTimes,
    this.totalCount,
  });

  factory DrawResultsResponse.fromJson(Map<String, dynamic> json) {
    final drawTimesData = json['draw_times'] as List?;
    final drawTimes = (drawTimesData ?? [])
        .map((item) => DrawResult.fromJson(item as Map<String, dynamic>))
        .toList();

    return DrawResultsResponse(
      message: json['message'] as String?,
      gameId: json['game_id'] as String?,
      drawDate: json['draw_date'] as String?,
      drawTimes: drawTimes,
      totalCount: json['total_count'] as int?,
    );
  }
}

class LiveDrawResult {
  final String id;
  final String gameId;
  final String? drawTimeId;
  final String drawDate;
  final List<String> result;
  final double winAmount;
  final String? updatedAt;

  LiveDrawResult({
    required this.id,
    required this.gameId,
    required this.drawTimeId,
    required this.drawDate,
    required this.result,
    required this.winAmount,
    required this.updatedAt,
  });

  factory LiveDrawResult.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    final parsedResult = rawResult is List
        ? rawResult.map((item) => item.toString()).toList()
        : <String>[];

    return LiveDrawResult(
      id: json['id'] as String? ?? '',
      gameId: json['game_id'] as String? ?? '',
      drawTimeId: json['draw_time_id'] as String?,
      drawDate: json['draw_date'] as String? ?? '',
      result: parsedResult,
      winAmount: (json['win_amount'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class DrawResultsService {
  static String get _baseUrl => '${AppConstants.apiBaseUrl}/draw-results';

  static Future<List<LiveDrawResult>> getLatestResults({
    String? drawDate,
  }) async {
    try {
      final authController = Get.find<AuthController>();
      final token = authController.token.value;

      final queryParams = <String, String>{};
      if (drawDate != null && drawDate.isNotEmpty) {
        queryParams['draw_date'] = drawDate;
      }

      final uri = Uri.parse(
        '$_baseUrl/latest',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch draw results: ${response.statusCode}');
      }

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      final data = jsonData['data'] as List? ?? const [];
      return data
          .map((item) => LiveDrawResult.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching draw results: $e');
    }
  }

  static Future<DrawResultsResponse?> getLatestResultsByGameAndDate({
    required String gameId,
    String? drawDate,
  }) async {
    try {
      final authController = Get.find<AuthController>();
      final token = authController.token.value;

      final queryParams = <String, String>{'game_id': gameId};

      if (drawDate != null && drawDate.isNotEmpty) {
        queryParams['draw_date'] = drawDate;
      }

      final uri = Uri.parse(
        '$_baseUrl/latest-by-game-date',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return DrawResultsResponse.fromJson(jsonData);
      } else {
        Get.snackbar(
          'Error',
          'Failed to fetch draw results: ${response.statusCode}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return null;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Error fetching draw results: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }
}
