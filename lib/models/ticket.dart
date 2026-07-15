class Ticket {
  final String? id;
  final String? ticketNo;
  final String? batchId;
  final List<String>? betIdList;
  final List<BetData>? betObjects;
  final String? status;
  final CustomerData? customer;
  final ClusterData? cluster;
  final String? createdAt;
  final String? paymentMethod;
  final String? accountNumber;
  final String? deletedAt;
  final double? winningPayout;
  final String? requestId;
  final String? requestType;
  final String? requestStatus;
  final String? requestRemarks;
  // Admin-configured void window data (optional, may be present in API)
  final String? voidExpiresAt; // explicit timestamp when voiding expires
  final int? voidWindowMinutes; // alternative: minutes from creation when voiding allowed
  // Reprint tracking
  final int? printCount;
  final int? reprintRequests;

  Ticket({
    this.id,
    this.ticketNo,
    this.batchId,
    this.betIdList,
    this.betObjects,
    this.status,
    this.customer,
    this.cluster,
    this.createdAt,
    this.paymentMethod,
    this.accountNumber,
    this.deletedAt,
    this.winningPayout,
    this.requestId,
    this.requestType,
    this.requestStatus,
    this.requestRemarks,
    this.voidExpiresAt,
    this.voidWindowMinutes,
    this.printCount,
    this.reprintRequests,
  });

  // Backward compatibility: return betObjects for display
  List<BetData>? get betIds => betObjects;
  bool get hasActiveRequest => requestId != null && requestId!.isNotEmpty;
  bool get hasPendingVoidRequest =>
      (status ?? '').toLowerCase() == 'pending_void' ||
      ((requestType ?? '').toLowerCase() == 'void_ticket' &&
          (requestStatus ?? '').toLowerCase() == 'pending');
  bool get hasPendingReprintRequest =>
      (requestType ?? '').toLowerCase() == 'reprint_ticket' &&
      (requestStatus ?? '').toLowerCase() == 'pending';
  bool get hasApprovedReprintRequest =>
      (requestType ?? '').toLowerCase() == 'reprint_ticket' &&
      (requestStatus ?? '').toLowerCase() == 'approved';

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as String?,
      ticketNo: json['ticket_no'] as String?,
      batchId: json['batch_id'] as String?,
      betIdList: (json['bet_ids'] as List?)?.cast<String>(),
      betObjects: (json['bet_objects'] as List?)
          ?.map((bet) => BetData.fromJson(bet as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String? ?? 'unknown',
      customer: json['customer'] != null
          ? CustomerData.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      cluster: json['cluster'] != null
          ? ClusterData.fromJson(json['cluster'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] as String?,
      paymentMethod: json['payment_method'] as String?,
      accountNumber: json['account_number'] as String?,
      deletedAt: json['deleted_at'] as String?,
      winningPayout: json['winning_payout']?.toDouble(),
      requestId: json['request_id'] as String?,
      requestType: json['request_type'] as String?,
      requestStatus: json['request_status'] as String?,
      requestRemarks: json['request_remarks'] as String?,
      voidExpiresAt: json['void_expires_at'] as String? ?? json['void_until'] as String?,
      voidWindowMinutes: json['void_window_minutes'] as int? ?? (json['void_window_minutes'] is String ? int.tryParse(json['void_window_minutes']) : null),
      printCount: (json['print_count'] is int)
          ? (json['print_count'] as int)
          : (json['print_count'] is String ? int.tryParse(json['print_count']) : null),
      reprintRequests: (json['reprint_requests'] is int)
          ? (json['reprint_requests'] as int)
          : (json['reprint_requests'] is String ? int.tryParse(json['reprint_requests']) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_no': ticketNo,
      'batch_id': batchId,
      'bet_ids': betIdList,
      'bet_objects': betObjects?.map((b) => b.toJson()).toList(),
      'status': status,
      'customer': customer?.toJson(),
      'cluster': cluster?.toJson(),
      'created_at': createdAt,
      'payment_method': paymentMethod,
      'account_number': accountNumber,
      'deleted_at': deletedAt,
      'winning_payout': winningPayout,
      'request_id': requestId,
      'request_type': requestType,
      'request_status': requestStatus,
      'request_remarks': requestRemarks,
      'void_expires_at': voidExpiresAt,
     'void_window_minutes': voidWindowMinutes,
     'print_count': printCount,
     'reprint_requests': reprintRequests,
   };
  }

  /// Helper: returns DateTime when voiding expires, if provided.
  DateTime? get voidExpires {
    if (voidExpiresAt == null) return null;
    try {
      return DateTime.parse(voidExpiresAt!).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Helper: compute if void window is still active based on either explicit expires timestamp
  /// or a window measured in minutes from ticket creation time.
  bool isVoidWindowActive() {
    final now = DateTime.now();
    final expires = voidExpires;
    if (expires != null) {
      return now.isBefore(expires);
    }
    if (voidWindowMinutes != null && createdAt != null) {
      try {
        final created = DateTime.parse(createdAt!).toLocal();
        final allowedUntil = created.add(Duration(minutes: voidWindowMinutes!));
        return now.isBefore(allowedUntil);
      } catch (_) {
        return true;
      }
    }
    // No admin config provided — default to allow voiding
    return true;
  }
}

class CustomerData {
  final String? id;
  final String? name;
  final String? email;
  final String? role;

  CustomerData({this.id, this.name, this.email, this.role});

  factory CustomerData.fromJson(Map<String, dynamic> json) {
    return CustomerData(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'role': role};
  }
}

class ClusterData {
  final String? id;
  final String? name;

  ClusterData({this.id, this.name});

  factory ClusterData.fromJson(Map<String, dynamic> json) {
    return ClusterData(
      id: json['id'] as String?,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}

class BetData {
  final String? id;
  final String? gameId;
  final String? number;
  final List<String>? digits;
  final double? straightBetAmount;
  final double? rambleBetAmount;
  final double? totalBetAmount;
  final String? status;
  final double? estPayout;
  final String? ticketNo;
  final String? createdAt;
  final String? gameName;
  final String? drawTime;
  final String? drawTimeId;
  final String? drawDate;

  BetData({
    this.id,
    this.gameId,
    this.number,
    this.digits,
    this.straightBetAmount,
    this.rambleBetAmount,
    this.totalBetAmount,
    this.status,
    this.estPayout,
    this.ticketNo,
    this.createdAt,
    this.gameName,
    this.drawTime,
    this.drawTimeId,
    this.drawDate,
  });

  factory BetData.fromJson(Map<String, dynamic> json) {
    // Handle digits as either a string (e.g. "{31,14}") or a List
    List<String>? parsedDigits;
    if (json['digits'] != null) {
      if (json['digits'] is String) {
        String digitsStr = (json['digits'] as String)
            .replaceAll('{', '')
            .replaceAll('}', '')
            .trim();
        if (digitsStr.isNotEmpty) {
          parsedDigits = digitsStr.split(',').map((d) => d.trim()).toList();
        } else {
          parsedDigits = <String>[];
        }
      } else if (json['digits'] is List) {
        parsedDigits = (json['digits'] as List)
            .map((d) => d.toString())
            .toList();
      }
    }
    return BetData(
      id: json['id'] as String?,
      gameId: json['game_id'] as String?,
      number: json['number'] as String?,
      digits: parsedDigits,
      straightBetAmount: (json['straight_bet_amount'] as num?)?.toDouble(),
      rambleBetAmount: (json['ramble_bet_amount'] as num?)?.toDouble(),
      totalBetAmount: (json['total_bet_amount'] as num?)?.toDouble(),
      status: json['status'] as String?,
      estPayout: (json['est_payout'] as num?)?.toDouble(),
      ticketNo: json['ticket_no'] as String?,
      createdAt: json['created_at'] as String?,
      gameName: json['game_name'] as String?,
      drawTime: json['draw_time'] as String?,
      drawTimeId: json['draw_time_id'] as String?,
      drawDate: json['draw_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game_id': gameId,
      'number': number,
      'digits': digits,
      'straight_bet_amount': straightBetAmount,
      'ramble_bet_amount': rambleBetAmount,
      'total_bet_amount': totalBetAmount,
      'status': status,
      'est_payout': estPayout,
      'ticket_no': ticketNo,
      'created_at': createdAt,
      'game_name': gameName,
      'draw_time': drawTime,
      'draw_time_id': drawTimeId,
    };
  }
}
