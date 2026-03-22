import 'package:flutter/material.dart';

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
  final List<dynamic> breakdown;

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
      breakdown: json['breakdown'] ?? [],
    );
  }
}
