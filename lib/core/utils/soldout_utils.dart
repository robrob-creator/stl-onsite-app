import 'dart:convert';
import 'dart:math' as math;
import 'package:onstite/models/bet_availability.dart';
import 'package:onstite/models/sold_out_row.dart';

// ─── Permutation Math ─────────────────────────────────────────────────────────

String normalizeCombination(List<String> digits) {
  final sorted = List<String>.from(digits)..sort();
  return sorted.join();
}

int countPermutations(List<String> digits) {
  final n = digits.length;
  final freq = <String, int>{};
  for (final d in digits) {
    freq[d] = (freq[d] ?? 0) + 1;
  }
  int result = _factorial(n);
  for (final count in freq.values) {
    result ~/= _factorial(count);
  }
  return result;
}

int _factorial(int n) {
  int r = 1;
  for (int i = 2; i <= n; i++) {
    r *= i;
  }
  return r;
}

List<String> generatePermutationValues(List<String> tokens) {
  final results = <String>{};
  final sorted = List<String>.from(tokens)..sort();
  final used = List<bool>.filled(sorted.length, false);

  void backtrack(List<String> current) {
    if (current.length == sorted.length) {
      results.add(current.join('|'));
      return;
    }
    for (int i = 0; i < sorted.length; i++) {
      if (used[i]) continue;
      if (i > 0 && !used[i - 1] && sorted[i] == sorted[i - 1]) continue;
      used[i] = true;
      current.add(sorted[i]);
      backtrack(current);
      current.removeLast();
      used[i] = false;
    }
  }

  backtrack([]);
  return results.toList();
}

String? validateRambolAmount(
  List<String> digits,
  double amount, {
  double? maxAmount,
}) {
  final permCount = countPermutations(digits);
  if (permCount <= 1) return 'Rambol not available — all digits are identical';
  if (amount < permCount) {
    return 'Minimum Rambol amount is ₱$permCount (₱1 per permutation × $permCount permutations)';
  }
  if (amount % permCount != 0) {
    return 'Rambol amount must be divisible by $permCount';
  }
  if (maxAmount != null && amount > maxAmount) {
    return 'Rambol amount exceeds maximum (₱$maxAmount)';
  }
  return null;
}

// ─── bet_numbers Parsing ──────────────────────────────────────────────────────

dynamic _normalizeBetNumbersInput(dynamic input) {
  if (input is! String) return input;
  final raw = input.trim();
  if (raw.isEmpty) return input;
  if (raw.startsWith('[') || raw.startsWith('{')) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return input;
    }
  }
  return input;
}

bool soldOutCoversGroupKey(dynamic betNumbers, String groupKey) {
  final normalized = _normalizeBetNumbersInput(betNumbers);

  if (normalized is List) {
    for (final bn in normalized) {
      if (bn is List) {
        final s = (bn.map((e) => '$e').toList()..sort()).join();
        if (s == groupKey) return true;
      } else {
        final sorted = '$bn'.split('').toList()..sort();
        if (sorted.join() == groupKey) return true;
      }
    }
    return false;
  }

  if (normalized is Map) {
    for (final v in normalized.values) {
      if (v is List) {
        final s = (v.map((e) => '$e').toList()..sort()).join();
        if (s == groupKey) return true;
      } else {
        final sorted = '$v'.split('').toList()..sort();
        if (sorted.join() == groupKey) return true;
      }
    }
    return false;
  }

  if (normalized is String) {
    for (final s in normalized.split(',')) {
      final sorted = s.trim().split('').toList()..sort();
      if (sorted.join() == groupKey) return true;
    }
    return false;
  }

  return false;
}

bool exactOrderInSoldOut(String exactNumber, dynamic betNumbers) {
  final normalized = _normalizeBetNumbersInput(betNumbers);
  final exactStr = exactNumber.trim();

  if (normalized is List) {
    for (final bn in normalized) {
      if (bn is List) {
        if (bn.map((e) => '$e').join() == exactStr) return true;
      } else {
        if ('$bn'.trim() == exactStr) return true;
      }
    }
    return false;
  }

  if (normalized is Map) {
    for (final v in normalized.values) {
      if (v is List) {
        if (v.map((e) => '$e').join() == exactStr) return true;
      } else {
        if ('$v'.trim() == exactStr) return true;
      }
    }
    return false;
  }

  if (normalized is String) {
    return normalized.split(',').any((s) => s.trim() == exactStr);
  }

  return false;
}

// ─── Limit Resolution ─────────────────────────────────────────────────────────

bool _inDateRange(DateTime? drawTs, DateTime? start, DateTime? end) {
  if (drawTs == null) return start == null && end == null;
  if (start != null && drawTs.isBefore(start)) return false;
  if (end != null && drawTs.isAfter(end)) return false;
  return true;
}

double? resolveGroupLimit({
  required String gameId,
  required String drawTimeId,
  required String drawDate,
  required String groupKey,
  required Map<String, double> gameSoldOutAmounts,
  required Map<String, List<SoldOutRow>> soldOutByGame,
}) {
  final rows = soldOutByGame[gameId] ?? [];
  final drawTs = DateTime.tryParse(drawDate);
  final drawDateKey = drawDate.length >= 10 ? drawDate.substring(0, 10) : null;

  for (final so in rows) {
    if (so.type == 'per schedule' || so.drawTimeId != null) {
      if (so.drawTimeId == null || so.drawTimeId != drawTimeId) continue;
    }
    if (!soldOutCoversGroupKey(so.betNumbers, groupKey)) continue;

    if (so.type == 'per schedule') {
      final startKey = so.dateStarted?.toIso8601String().substring(0, 10);
      if (drawDateKey == null || startKey == null || drawDateKey != startKey) {
        continue;
      }
      return so.maxAmount;
    }

    if (!_inDateRange(drawTs, so.dateStarted, so.dateEnded)) continue;
    return so.maxAmount;
  }

  return gameSoldOutAmounts[gameId];
}

double? resolveTargetLimit({
  required String gameId,
  required String drawTimeId,
  required String drawDate,
  required String exactNumber,
  required Map<String, double> gameSoldOutAmounts,
  required Map<String, List<SoldOutRow>> soldOutByGame,
}) {
  final rows = soldOutByGame[gameId] ?? [];
  final drawTs = DateTime.tryParse(drawDate);
  final drawDateKey = drawDate.length >= 10 ? drawDate.substring(0, 10) : null;

  for (final so in rows) {
    if (so.type == 'per schedule' || so.drawTimeId != null) {
      if (so.drawTimeId == null || so.drawTimeId != drawTimeId) continue;
    }
    if (!exactOrderInSoldOut(exactNumber, so.betNumbers)) continue;

    if (so.type == 'per schedule') {
      final startKey = so.dateStarted?.toIso8601String().substring(0, 10);
      if (drawDateKey == null || startKey == null || drawDateKey != startKey) {
        continue;
      }
      return so.maxAmount;
    }

    if (!_inDateRange(drawTs, so.dateStarted, so.dateEnded)) continue;
    return so.maxAmount;
  }

  return gameSoldOutAmounts[gameId];
}

// ─── Exposure Accumulator ─────────────────────────────────────────────────────

class ExposureAccumulator {
  final Map<String, double> exactTargetExposure = {};
  final Map<String, double> perPermRambolExposure = {};
  final Map<String, double> maxTargetExposureByGroup = {};

  void accumulate(List<Map<String, dynamic>> pendingBets) {
    for (final bet in pendingBets) {
      final raw = bet['digits'];
      final digits = (raw is List) ? raw.map((e) => '$e').toList() : <String>[];
      final gk = normalizeCombination(digits);
      final exactNum = digits.join();
      final gameId = bet['game_id'] as String? ?? '';
      final drawId = bet['draw_id'] as String? ?? '';
      final drawDate = bet['draw_date'] as String? ?? '';
      final groupKey = '$gameId::$gk::$drawId::$drawDate';
      final exactKey = '$gameId::$exactNum::$drawId::$drawDate';
      final amount = (bet['total_bet_amount'] as num?)?.toDouble() ?? 0.0;

      if (_isRambol(bet)) {
        final permCount = countPermutations(digits);
        final perPerm = permCount > 0 ? amount / permCount : amount;
        perPermRambolExposure[groupKey] =
            (perPermRambolExposure[groupKey] ?? 0) + perPerm;
      } else {
        exactTargetExposure[exactKey] =
            (exactTargetExposure[exactKey] ?? 0) + amount;
        maxTargetExposureByGroup[groupKey] = math.max(
          maxTargetExposureByGroup[groupKey] ?? 0,
          exactTargetExposure[exactKey]!,
        );
      }
    }
  }

  static bool _isRambol(Map<String, dynamic> bet) {
    final t = '${bet['bet_type'] ?? ''}'.toLowerCase();
    if (t == 'ramble' || t == 'rambol') return true;
    if (t == 'straight' || t == 'target') return false;
    final ramble = (bet['ramble_bet_amount'] as num?)?.toDouble() ?? 0;
    final straight = (bet['straight_bet_amount'] as num?)?.toDouble() ?? 0;
    return ramble > 0 && straight <= 0;
  }
}

// ─── Availability Check ───────────────────────────────────────────────────────

class _GroupAnalysis {
  final double? limit;
  final double exactTargetExposure;
  final double existingMaxTarget;
  final double perPermRambolExposure;
  final double currentPermExposure;
  final double? permRemaining;
  final double targetAmount;
  final double rambolPerPerm;
  final double rambolTotalAmount;
  final int permCount;
  final bool targetFits;
  final double? rambolRemaining;
  final bool rambolFitsOwnRules;
  final double? remainingAfterTarget;
  final bool anyPermSoldOut;

  const _GroupAnalysis({
    required this.limit,
    required this.exactTargetExposure,
    required this.existingMaxTarget,
    required this.perPermRambolExposure,
    required this.currentPermExposure,
    required this.permRemaining,
    required this.targetAmount,
    required this.rambolPerPerm,
    required this.rambolTotalAmount,
    required this.permCount,
    required this.targetFits,
    required this.rambolRemaining,
    required this.rambolFitsOwnRules,
    required this.remainingAfterTarget,
    required this.anyPermSoldOut,
  });
}

List<BetAvailabilityResult> checkAvailability({
  required List<NormalizedBet> bets,
  required ExposureAccumulator db,
  required Map<String, double> gameSoldOutAmounts,
  required Map<String, double> gameMaxRambolAmounts,
  required Map<String, List<SoldOutRow>> soldOutByGame,
}) {
  final requestTargetByExact = <String, double>{};
  final requestRambolPerPermByGroup = <String, double>{};
  final incomingTargetByExact = <String, double>{};
  final incomingRambolPerPermByGroup = <String, double>{};
  final groupRepresentativeExact = <String, String>{};

  for (final bet in bets) {
    final groupKey =
        '${bet.gameId}::${bet.groupKey}::${bet.drawId}::${bet.drawDate}';
    final exactKey =
        '${bet.gameId}::${bet.number}::${bet.drawId}::${bet.drawDate}';

    if (bet.betType == BetType.target) {
      requestTargetByExact[exactKey] =
          (requestTargetByExact[exactKey] ?? 0) + bet.amount;
      if (!bet.fromCart) {
        incomingTargetByExact[exactKey] =
            (incomingTargetByExact[exactKey] ?? 0) + bet.amount;
      }
      groupRepresentativeExact[groupKey] = exactKey;
    } else {
      final permCount = countPermutations(bet.digits);
      final perPerm = permCount > 0 ? bet.amount / permCount : bet.amount;
      requestRambolPerPermByGroup[groupKey] =
          (requestRambolPerPermByGroup[groupKey] ?? 0) + perPerm;
      if (!bet.fromCart) {
        incomingRambolPerPermByGroup[groupKey] =
            (incomingRambolPerPermByGroup[groupKey] ?? 0) + perPerm;
      }
      groupRepresentativeExact.putIfAbsent(groupKey, () => exactKey);
    }
  }

  final groupAnalyses = <String, _GroupAnalysis>{};

  for (final bet in bets) {
    final gk =
        '${bet.gameId}::${bet.groupKey}::${bet.drawId}::${bet.drawDate}';
    if (groupAnalyses.containsKey(gk)) continue;

    final limit = resolveGroupLimit(
      gameId: bet.gameId,
      drawTimeId: bet.drawTimeId,
      drawDate: bet.drawDate,
      groupKey: bet.groupKey,
      gameSoldOutAmounts: gameSoldOutAmounts,
      soldOutByGame: soldOutByGame,
    );

    final refExactKey = groupRepresentativeExact[gk] ??
        '${bet.gameId}::${bet.number}::${bet.drawId}::${bet.drawDate}';

    final exactTargetExp = db.exactTargetExposure[refExactKey] ?? 0;
    final cartRambolPerPerm = math.max(
      0.0,
      (requestRambolPerPermByGroup[gk] ?? 0) -
          (incomingRambolPerPermByGroup[gk] ?? 0),
    );
    final perPermRambolExp =
        (db.perPermRambolExposure[gk] ?? 0) + cartRambolPerPerm;
    final currentPermExp = exactTargetExp + perPermRambolExp;
    final permRemaining =
        limit != null ? math.max(0.0, limit - currentPermExp) : null;

    final targetAmount = requestTargetByExact[refExactKey] ?? 0;
    final permCount = countPermutations(bet.digits);
    final rambolPerPerm = requestRambolPerPermByGroup[gk] ?? 0;
    final incomingRambolPerPerm = incomingRambolPerPermByGroup[gk] ?? 0;
    final rambolTotalAmount = rambolPerPerm * permCount;

    final targetFits = permRemaining == null || targetAmount <= permRemaining;

    final existingMaxTarget = db.maxTargetExposureByGroup[gk] ?? 0;
    final worstPermBeforeTarget = existingMaxTarget + perPermRambolExp;
    final rambolRemaining = limit != null
        ? math.max(0.0, limit - worstPermBeforeTarget)
        : null;

    final anyPermSoldOut =
        limit != null && existingMaxTarget + perPermRambolExp >= limit;

    final rambolFitsOwnRules = rambolRemaining == null ||
        (!anyPermSoldOut && incomingRambolPerPerm <= rambolRemaining);

    final newTargetPermExp = exactTargetExp + targetAmount;
    final worstPermAfterTarget =
        math.max(existingMaxTarget, newTargetPermExp) + perPermRambolExp;
    final remainingAfterTarget =
        limit != null ? math.max(0.0, limit - worstPermAfterTarget) : null;

    groupAnalyses[gk] = _GroupAnalysis(
      limit: limit,
      exactTargetExposure: exactTargetExp,
      existingMaxTarget: existingMaxTarget,
      perPermRambolExposure: perPermRambolExp,
      currentPermExposure: currentPermExp,
      permRemaining: permRemaining,
      targetAmount: targetAmount,
      rambolPerPerm: rambolPerPerm,
      rambolTotalAmount: rambolTotalAmount,
      permCount: permCount,
      targetFits: targetFits,
      rambolRemaining: rambolRemaining,
      rambolFitsOwnRules: rambolFitsOwnRules,
      remainingAfterTarget: remainingAfterTarget,
      anyPermSoldOut: anyPermSoldOut,
    );
  }

  return bets.map((bet) {
    final gk =
        '${bet.gameId}::${bet.groupKey}::${bet.drawId}::${bet.drawDate}';
    final exactMapKey =
        '${bet.gameId}::${bet.number}::${bet.drawId}::${bet.drawDate}';
    final analysis = groupAnalyses[gk]!;

    final exactTargetLimit = resolveTargetLimit(
      gameId: bet.gameId,
      drawTimeId: bet.drawTimeId,
      drawDate: bet.drawDate,
      exactNumber: bet.number,
      gameSoldOutAmounts: gameSoldOutAmounts,
      soldOutByGame: soldOutByGame,
    );

    final exactTargetExp = db.exactTargetExposure[exactMapKey] ?? 0;
    final totalGroupExpForTarget =
        exactTargetExp + analysis.perPermRambolExposure;
    final exactRemaining = exactTargetLimit != null
        ? math.max(0.0, exactTargetLimit - totalGroupExpForTarget)
        : null;

    final targetRequestAmount = requestTargetByExact[exactMapKey] ?? 0;
    final targetAllowed =
        exactRemaining == null || targetRequestAmount <= exactRemaining;

    final rambolAmountError = bet.betType == BetType.rambol
        ? validateRambolAmount(
            bet.digits,
            bet.amount,
            maxAmount: gameMaxRambolAmounts[bet.gameId],
          )
        : null;
    final rambolAllowed =
        rambolAmountError == null && analysis.rambolFitsOwnRules;
    final rambolAvailableAmount = analysis.rambolRemaining != null
        ? analysis.rambolRemaining! * analysis.permCount
        : null;

    final isTarget = bet.betType == BetType.target;
    final exceeds = isTarget ? !targetAllowed : !rambolAllowed;

    final betPermRemaining = exactRemaining;
    final state = betPermRemaining != null && betPermRemaining <= 0
        ? AvailabilityState.soldOut
        : (!targetAllowed || !rambolAllowed)
            ? AvailabilityState.partiallySold
            : AvailabilityState.open;

    return BetAvailabilityResult(
      gameId: bet.gameId,
      number: bet.number,
      groupKey: bet.groupKey,
      betType: bet.betType,
      drawId: bet.drawId,
      drawDate: bet.drawDate,
      currentExposure: totalGroupExpForTarget,
      requestedAmount: bet.amount,
      availableAmount: isTarget ? exactRemaining : rambolAvailableAmount,
      limit: isTarget ? exactTargetLimit : analysis.limit,
      exceeds: exceeds,
      state: state,
      permutationCount: analysis.permCount,
      minRambolAmount:
          analysis.permCount > 1 ? analysis.permCount.toDouble() : null,
      anyPermSoldOut: analysis.anyPermSoldOut,
      target: BetTypeAvailability(
        allowed: targetAllowed,
        availableAmount: exactRemaining,
        reason: targetAllowed
            ? null
            : 'Target ${bet.number} is not available — limit reached',
      ),
      rambol: BetTypeAvailability(
        allowed: rambolAllowed,
        availableAmount: rambolAvailableAmount,
        reason: rambolAmountError ??
            (!analysis.rambolFitsOwnRules
                ? analysis.anyPermSoldOut
                    ? 'Rambol disabled — a permutation in group ${bet.groupKey} is sold out'
                    : 'Rambol not available — group ${bet.groupKey} limit reached'
                : null),
      ),
    );
  }).toList();
}

// ─── Advance Bet Gate ─────────────────────────────────────────────────────────

bool canShowAdvanceButton({
  required SoldOutRow? soldOutRow,
  required DateTime nextDrawDate,
}) {
  if (soldOutRow == null) return true;
  if (soldOutRow.type == 'special') return false;
  if (soldOutRow.dateEnded == null) return true;
  return nextDrawDate.isAfter(soldOutRow.dateEnded!);
}

// ─── Available Amount for "Update" Button ─────────────────────────────────────

double computeAvailableForAdd({
  required double serverAvailable,
  required List<Map<String, dynamic>> cartBets,
  required String gameId,
  required String number,
  required String drawId,
  required BetType betType,
}) {
  double cartTotal = 0;
  for (final b in cartBets) {
    final bDigits = (b['digits'] as List?)?.map((e) => '$e').join() ?? '';
    final bGame = b['game_id'] as String? ?? '';
    final bDraw = b['draw_id'] as String? ?? '';
    final bType = b['bet_type'] as BetType?;
    if (bGame == gameId &&
        bDigits == number &&
        bDraw == drawId &&
        bType == betType) {
      cartTotal += (b['amount'] as num?)?.toDouble() ?? 0;
    }
  }
  return math.max(0.0, serverAvailable - cartTotal);
}

// ─── Skip Logic ───────────────────────────────────────────────────────────────

bool canSkipAvailabilityCheck({
  required bool cacheReady,
  required bool hasSoldOutEntry,
  required double? gameSoldOutAmount,
}) {
  return cacheReady &&
      !hasSoldOutEntry &&
      (gameSoldOutAmount == null || gameSoldOutAmount == 0);
}

// ─── Balance (Integer Cents) ──────────────────────────────────────────────────

int computeTotalBetAmountCents(List<double> amounts) {
  return amounts.fold(0, (sum, a) => sum + (a * 100).round());
}

double centsToAmount(int cents) => cents / 100.0;

// ─── Cutoff Time Check ────────────────────────────────────────────────────────

bool isWithinCutoffPeriod({
  required String timeLabel,
  required int cutOffTimeMinutes,
}) {
  final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false)
      .firstMatch(timeLabel);
  if (match == null) return false;

  int hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final period = match.group(3)!.toUpperCase();

  if (period == 'PM' && hour != 12) hour += 12;
  if (period == 'AM' && hour == 12) hour = 0;

  final now = DateTime.now();
  var drawTime = DateTime(now.year, now.month, now.day, hour, minute);
  if (drawTime.isBefore(now)) drawTime = drawTime.add(const Duration(days: 1));

  final cutoffStart = drawTime.subtract(Duration(minutes: cutOffTimeMinutes));
  return now.isAfter(cutoffStart) && now.isBefore(drawTime);
}
