class Game {
  final String id;
  final String name;
  final List<Cluster> clusters;
  final List<DrawTime> drawTimes;
  final String type;
  final String subCategory;
  final int minNumber;
  final int maxNumber;
  final int numberOfCombinations;
  final bool enableStraight;
  final bool enableRamble;
  final int minStraightBet;
  final int maxStraightBet;
  final int? minRambleBet;
  final int? maxRambleBet;
  final int straightMultiplier;
  final int? rambleMultiplier;
  final int? soldOutAmount;
  final String drawType;
  final String? imageUrl;
  final String status;
  final bool isActive;
  final String createdAt;

  Game({
    required this.id,
    required this.name,
    required this.clusters,
    required this.drawTimes,
    required this.type,
    required this.subCategory,
    required this.minNumber,
    required this.maxNumber,
    required this.numberOfCombinations,
    required this.enableStraight,
    required this.enableRamble,
    required this.minStraightBet,
    required this.maxStraightBet,
    this.minRambleBet,
    this.maxRambleBet,
    required this.straightMultiplier,
    this.rambleMultiplier,
    this.soldOutAmount,
    required this.drawType,
    this.imageUrl,
    required this.status,
    required this.isActive,
    required this.createdAt,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as String,
      name: json['name'] as String,
      clusters:
          (json['clusters'] as List?)
              ?.map((c) => Cluster.fromJson(c))
              .toList() ??
          [],
      drawTimes:
          (json['draw_times'] as List?)
              ?.map((d) => DrawTime.fromJson(d))
              .toList() ??
          [],
      type: json['type'] as String? ?? 'lottery',
      subCategory: json['sub_category'] as String? ?? '',
      minNumber: json['min_number'] as int? ?? 0,
      maxNumber: json['max_number'] as int? ?? 0,
      numberOfCombinations: json['number_of_combinations'] as int? ?? 1,
      enableStraight: json['enable_straight'] as bool? ?? true,
      enableRamble: json['enable_ramble'] as bool? ?? false,
      minStraightBet: json['min_straight_bet'] as int? ?? 0,
      maxStraightBet: json['max_straight_bet'] as int? ?? 0,
      minRambleBet: json['min_ramble_bet'] as int?,
      maxRambleBet: json['max_ramble_bet'] as int?,
      straightMultiplier: json['straight_multiplier'] as int? ?? 0,
      rambleMultiplier: json['ramble_multiplier'] as int?,
      soldOutAmount: json['sold_out_amount'] as int?,
      drawType: json['draw_type'] as String? ?? 'National',
      imageUrl: json['image_url'] as String?,
      status: json['status'] as String? ?? 'active',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'clusters': clusters.map((c) => c.toJson()).toList(),
      'draw_times': drawTimes.map((d) => d.toJson()).toList(),
      'type': type,
      'sub_category': subCategory,
      'min_number': minNumber,
      'max_number': maxNumber,
      'number_of_combinations': numberOfCombinations,
      'enable_straight': enableStraight,
      'enable_ramble': enableRamble,
      'min_straight_bet': minStraightBet,
      'max_straight_bet': maxStraightBet,
      'min_ramble_bet': minRambleBet,
      'max_ramble_bet': maxRambleBet,
      'straight_multiplier': straightMultiplier,
      'ramble_multiplier': rambleMultiplier,
      'sold_out_amount': soldOutAmount,
      'draw_type': drawType,
      'image_url': imageUrl,
      'status': status,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
}

class Cluster {
  final String id;
  final String name;
  final String code;
  final bool isActive;
  final String createdAt;
  final String? deletedAt;

  Cluster({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    required this.createdAt,
    this.deletedAt,
  });

  factory Cluster.fromJson(Map<String, dynamic> json) {
    return Cluster(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      isActive: json['is_active'] as bool,
      createdAt: json['created_at'] as String,
      deletedAt: json['deleted_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'is_active': isActive,
      'created_at': createdAt,
      'deleted_at': deletedAt,
    };
  }
}

class DrawTime {
  final String id;
  final String drawTime;
  final int cutoffMinutes;
  final bool isActive;
  final String createdAt;
  final String? deletedAt;

  DrawTime({
    required this.id,
    required this.drawTime,
    required this.cutoffMinutes,
    required this.isActive,
    required this.createdAt,
    this.deletedAt,
  });

  factory DrawTime.fromJson(Map<String, dynamic> json) {
    return DrawTime(
      id: json['id'] as String,
      drawTime: json['draw_time'] as String,
      cutoffMinutes: json['cutoff_minutes'] as int,
      isActive: json['is_active'] as bool,
      createdAt: json['created_at'] as String,
      deletedAt: json['deleted_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'draw_time': drawTime,
      'cutoff_minutes': cutoffMinutes,
      'is_active': isActive,
      'created_at': createdAt,
      'deleted_at': deletedAt,
    };
  }

  /// Extract time string in HH:MM AM/PM format from the draw_time field
  String getFormattedTime() {
    try {
      // Parse ISO 8601 format: "0000-01-01T10:30:00Z"
      final parts = drawTime.split('T');
      if (parts.length > 1) {
        final timeString = parts[1].substring(0, 5); // HH:MM
        final timeParts = timeString.split(':');

        if (timeParts.length == 2) {
          int hour = int.parse(timeParts[0]);
          final minute = timeParts[1];

          // Convert to 12-hour format
          final String period = hour >= 12 ? 'PM' : 'AM';
          if (hour > 12) {
            hour = hour - 12;
          } else if (hour == 0) {
            hour = 12;
          }

          return '$hour:$minute $period';
        }
      }
    } catch (e) {
      // Fallback
    }
    return drawTime;
  }

  /// Check if draw time is still available based on current time and cutoff
  bool isAvailable() {
    try {
      // Parse the ISO 8601 format: "0000-01-01T10:30:00Z"
      final now = DateTime.now();
      final parts = drawTime.split('T');

      if (parts.length < 2) return false;

      // Extract time parts
      final timeParts = parts[1].substring(0, 5).split(':');
      if (timeParts.length != 2) return false;

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Create a DateTime for today's draw time
      final drawDateTime = DateTime(now.year, now.month, now.day, hour, minute);

      // If the draw time has already passed today, it is no longer available
      if (drawDateTime.isBefore(now)) {
        return false;
      }

      // Calculate cutoff time (X minutes before the draw)
      final cutoffDateTime = drawDateTime.subtract(
        Duration(minutes: cutoffMinutes),
      );

      // Draw time is available only if current time is before the cutoff
      return now.isBefore(cutoffDateTime);
    } catch (e) {
      return true; // Default to available if parsing fails
    }
  }
}
