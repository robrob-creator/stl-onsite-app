# Soldout System — Flutter Implementation Guide

> App: STL Agent App (onstite)
> Date: 2026-05-21
> Approach: REST via `http` package (no Supabase client)

---

## Overview

Replace the current binary sold-out check (true/false) with a full client-side availability system that:

- Fetches `sold_out` rows and pending exposure from backend
- Computes remaining capacity locally using permutation math
- Shows conflict modals with actionable options (update amount / advance bet)
- Runs two-pass validation before final submit

---

## Implementation Order

Follow this order strictly — each layer depends on the one before it.

```
1. Models
2. Utils (pure logic)
3. Service layer (HTTP)
4. Controller updates
5. UI widgets (modals)
6. BetEntryPage wiring
```

---

## Step 1 — New Models

### `lib/models/sold_out_row.dart`

```dart
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
```

---

### `lib/models/bet_availability.dart`

```dart
import 'dart:math' as math;

enum BetType { target, rambol }

enum AvailabilityState { open, partiallySold, soldOut }

class NormalizedBet {
  final String gameId;
  final List<String> digits;
  final String number;       // digits.join("")
  final String groupKey;     // digits sorted + joined
  final BetType betType;
  final String drawId;
  final String drawDate;     // "YYYY-MM-DD"
  final String drawTimeId;
  final double amount;
  final bool fromCart;

  NormalizedBet({
    required this.gameId,
    required this.digits,
    required this.number,
    required this.groupKey,
    required this.betType,
    required this.drawId,
    required this.drawDate,
    required this.drawTimeId,
    required this.amount,
    this.fromCart = false,
  });
}

class BetTypeAvailability {
  final bool allowed;
  final double? availableAmount;
  final String? reason;

  const BetTypeAvailability({
    required this.allowed,
    this.availableAmount,
    this.reason,
  });
}

class BetAvailabilityResult {
  final String gameId;
  final String number;
  final String groupKey;
  final BetType betType;
  final String drawId;
  final String drawDate;
  final double currentExposure;
  final double requestedAmount;
  final double? availableAmount;
  final double? limit;
  final bool exceeds;
  final BetTypeAvailability target;
  final BetTypeAvailability rambol;
  final AvailabilityState state;
  final int permutationCount;
  final double? minRambolAmount;
  final bool anyPermSoldOut;

  const BetAvailabilityResult({
    required this.gameId,
    required this.number,
    required this.groupKey,
    required this.betType,
    required this.drawId,
    required this.drawDate,
    required this.currentExposure,
    required this.requestedAmount,
    this.availableAmount,
    this.limit,
    required this.exceeds,
    required this.target,
    required this.rambol,
    required this.state,
    required this.permutationCount,
    this.minRambolAmount,
    required this.anyPermSoldOut,
  });
}
```

---

## Step 2 — Utils (Pure Logic)

### `lib/core/utils/soldout_utils.dart`

Full file — no imports from GetX or http. Pure Dart only.

```dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:onstite/models/bet_availability.dart';
import 'package:onstite/models/sold_out_row.dart';

// ─── Permutation Math ────────────────────────────────────────────────────────

String normalizeCombination(List<String> digits) {
  final sorted = List<String>.from(digits)..sort();
  return sorted.join();
}

int countPermutations(List<String> digits) {
  final n = digits.length;
  final freq = <String, int>{};
  for (final d in digits) freq[d] = (freq[d] ?? 0) + 1;
  int result = _factorial(n);
  for (final count in freq.values) result ~/= _factorial(count);
  return result;
}

int _factorial(int n) {
  int r = 1;
  for (int i = 2; i <= n; i++) r *= i;
  return r;
}

List<String> generatePermutationValues(List<String> tokens) {
  final results = <String>{};
  final used = List<bool>.filled(tokens.length, false);

  void backtrack(List<String> current) {
    if (current.length == tokens.length) {
      results.add(current.join('|'));
      return;
    }
    for (int i = 0; i < tokens.length; i++) {
      if (used[i]) continue;
      if (i > 0 && !used[i - 1] && tokens[i] == tokens[i - 1]) continue;
      used[i] = true;
      current.add(tokens[i]);
      backtrack(current);
      current.removeLast();
      used[i] = false;
    }
  }

  final sorted = List<String>.from(tokens)..sort();
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

// ─── bet_numbers Parsing ─────────────────────────────────────────────────────

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

// ─── Limit Resolution ────────────────────────────────────────────────────────

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

// ─── Exposure Accumulator ────────────────────────────────────────────────────

class ExposureAccumulator {
  final Map<String, double> exactTargetExposure = {};
  final Map<String, double> perPermRambolExposure = {};
  final Map<String, double> maxTargetExposureByGroup = {};

  void accumulate(List<Map<String, dynamic>> pendingBets) {
    for (final bet in pendingBets) {
      final raw = bet['digits'];
      final digits = (raw is List)
          ? raw.map((e) => '$e').toList()
          : <String>[];
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

// ─── Available Amount for "Update" Button ────────────────────────────────────

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
    if (bGame == gameId && bDigits == number && bDraw == drawId && bType == betType) {
      cartTotal += (b['amount'] as num?)?.toDouble() ?? 0;
    }
  }
  return math.max(0.0, serverAvailable - cartTotal);
}

// ─── Skip Logic ──────────────────────────────────────────────────────────────

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
```

---

## Step 3 — Service Layer

### `lib/core/services/sold_out_service.dart`

```dart
import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:onstite/controllers/auth_controller.dart';
import 'package:onstite/core/app_constants.dart';
import 'package:onstite/models/sold_out_row.dart';

class SoldOutService {
  static Future<List<SoldOutRow>> fetchSoldOutRows({
    List<String>? gameIds,
  }) async {
    final token = Get.find<AuthController>().token.value;
    final queryParams = gameIds != null && gameIds.isNotEmpty
        ? '?game_ids=${gameIds.join(',')}'
        : '';

    final response = await http.get(
      Uri.parse('${AppConstants.apiBaseUrl}/sold-out/list$queryParams'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['sold_out'] as List? ?? [];
      return list.map((e) => SoldOutRow.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch sold_out rows: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> fetchPendingExposure({
    required List<String> gameIds,
    required List<String> drawIds,
  }) async {
    final token = Get.find<AuthController>().token.value;
    final params =
        'game_ids=${gameIds.join(',')}&draw_ids=${drawIds.join(',')}';

    final response = await http.get(
      Uri.parse(
          '${AppConstants.apiBaseUrl}/bets/pending-exposure?$params'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['bets'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
    }
    throw Exception(
        'Failed to fetch pending exposure: ${response.statusCode}');
  }
}
```

---

## Step 4 — Controller Updates

### Changes to `lib/controllers/lottery_controller.dart`

#### 4a — Add cache fields (top of class)

```dart
// Sold-out cache
List<SoldOutRow> _cachedSoldOutRows = [];
DateTime? _soldOutCacheExpiry;
static const _soldOutCacheDuration = Duration(minutes: 5);

Map<String, List<SoldOutRow>> get _soldOutByGame {
  final map = <String, List<SoldOutRow>>{};
  for (final row in _cachedSoldOutRows) {
    map.putIfAbsent(row.gameId, () => []).add(row);
  }
  return map;
}
```

#### 4b — Cache loader

```dart
Future<void> _ensureSoldOutCache() async {
  final now = DateTime.now();
  if (_soldOutCacheExpiry != null && now.isBefore(_soldOutCacheExpiry!)) return;
  try {
    _cachedSoldOutRows = await SoldOutService.fetchSoldOutRows(
      gameIds: games.map((g) => g.id).toList(),
    );
    _soldOutCacheExpiry = now.add(_soldOutCacheDuration);
  } catch (_) {
    // Keep stale cache on failure — fail open
  }
}
```

#### 4c — Replace `isBetAvailable()` with full check

```dart
Future<BetAvailabilityResult?> checkBetAvailability({
  required List<String> digits,
  required double targetAmount,
  required double rambolAmount,
}) async {
  final game = currentGame;
  if (game == null) return null;

  final drawTimeId = selectedTime.value;
  final drawDate = DateTime.now().toIso8601String().substring(0, 10);

  // Skip check if no limits configured
  await _ensureSoldOutCache();
  final hasSoldOutEntry = _cachedSoldOutRows.any((r) => r.gameId == game.id);
  if (canSkipAvailabilityCheck(
    cacheReady: _soldOutCacheExpiry != null,
    hasSoldOutEntry: hasSoldOutEntry,
    gameSoldOutAmount: game.soldOutAmount?.toDouble(),
  )) return null;  // null = open, skip modal

  // Fetch exposure
  List<Map<String, dynamic>> pendingBets = [];
  try {
    pendingBets = await SoldOutService.fetchPendingExposure(
      gameIds: [game.id],
      drawIds: [drawTimeId],
    );
  } catch (_) {
    return null;  // fail open
  }

  final db = ExposureAccumulator()..accumulate(pendingBets);
  final groupKey = normalizeCombination(digits);

  final betsToCheck = <NormalizedBet>[];
  if (targetAmount > 0) {
    betsToCheck.add(NormalizedBet(
      gameId: game.id,
      digits: digits,
      number: digits.join(),
      groupKey: groupKey,
      betType: BetType.target,
      drawId: drawTimeId,
      drawDate: drawDate,
      drawTimeId: drawTimeId,
      amount: targetAmount,
    ));
  }
  if (rambolAmount > 0) {
    betsToCheck.add(NormalizedBet(
      gameId: game.id,
      digits: digits,
      number: digits.join(),
      groupKey: groupKey,
      betType: BetType.rambol,
      drawId: drawTimeId,
      drawDate: drawDate,
      drawTimeId: drawTimeId,
      amount: rambolAmount,
    ));
  }

  if (betsToCheck.isEmpty) return null;

  final gameSoldOutAmounts = {
    for (final g in games)
      if (g.soldOutAmount != null) g.id: g.soldOutAmount!.toDouble()
  };
  final gameMaxRambolAmounts = {
    for (final g in games)
      if (g.maxRambleBet != null) g.id: g.maxRambleBet!.toDouble()
  };

  final results = checkAvailability(
    bets: betsToCheck,
    db: db,
    gameSoldOutAmounts: gameSoldOutAmounts,
    gameMaxRambolAmounts: gameMaxRambolAmounts,
    soldOutByGame: _soldOutByGame,
  );

  // Return the first conflicting result, or the first result if all open
  return results.firstWhere(
    (r) => r.exceeds,
    orElse: () => results.first,
  );
}
```

#### 4d — Invalidate cache on WebSocket event

In `_subscribeToWebSocketEvents()`, add:

```dart
final unsubSoldOut = ws.on('sold_out.updated', (_) {
  _soldOutCacheExpiry = null;  // force refresh on next check
});
subscriptions.add(unsubSoldOut);
```

#### 4e — Two-pass submit validation

In `submitBets()`, before the HTTP call, add:

```dart
// Pass 1 — validate all Target bets
// Pass 2 — validate all Rambol bets vs post-Target state
// If any bet fails, show snackbar and abort
// Implementation: call checkAvailability with all draftBets as NormalizedBet list
// where fromCart = true for all, then check results for exceeds = true
```

Full two-pass implementation depends on draft bet structure — adapt as needed.

---

## Step 5 — UI Widgets

### `lib/widgets/conflict_notice_modal.dart`

Show when a single bet type exceeds limit.

```
┌─────────────────────────────┐
│  ⚠️  Limited Availability   │
│                             │
│  "123" — Target             │
│  ₱200 available             │
│                             │
│  [Yes, update to ₱200]      │
│  [No, I'll adjust manually] │
│  [Place advance ₱800]       │  ← only if canShowAdvanceButton
└─────────────────────────────┘
```

```dart
class ConflictNoticeModal extends StatelessWidget {
  final BetAvailabilityResult result;
  final double requestedAmount;
  final VoidCallback? onUpdateAmount;   // tapped "Yes, update to ₱X"
  final VoidCallback? onAdjustManually; // tapped "No, adjust manually"
  final VoidCallback? onPlaceAdvance;   // null = hide advance button

  const ConflictNoticeModal({
    super.key,
    required this.result,
    required this.requestedAmount,
    this.onUpdateAmount,
    this.onAdjustManually,
    this.onPlaceAdvance,
  });

  // ... build the modal using AppColors, AppTextStyles, AppSpacing
}
```

### `lib/widgets/batch_bet_choice_modal.dart`

Show when both Target and Rambol exceed limit — let user pick which type to place.

```
┌─────────────────────────────┐
│  Choose Bet Type            │
│                             │
│  Both types have limits.    │
│  Which would you like?      │
│                             │
│  [Target  — ₱200 remaining] │
│  [Rambol  — ₱300 remaining] │
└─────────────────────────────┘
```

---

## Step 6 — BetEntryPage Wiring

Replace lines 979–1116 in `bet_entry_page.dart`:

```dart
// OLD: show spinner → isBetAvailable() → bool → show sold-out modal
// NEW: show spinner → checkBetAvailability() → BetAvailabilityResult? → route to correct modal

final result = await controller.checkBetAvailability(
  digits: digits,
  targetAmount: targetAmount.toDouble(),
  rambolAmount: rambolAmount.toDouble(),
);

if (Get.isDialogOpen ?? false) Get.back();

if (result == null || !result.exceeds) {
  // Open → proceed to addBet
} else if (result.betType == BetType.target && targetAmount > 0 && rambolAmount > 0) {
  // Both types placed and conflict → BatchBetChoiceModal
} else {
  // Single type conflict → ConflictNoticeModal
}
```

---

## File Checklist

| File                                      | Action                                                            |
| ----------------------------------------- | ----------------------------------------------------------------- |
| `lib/models/sold_out_row.dart`            | Create                                                            |
| `lib/models/bet_availability.dart`        | Create                                                            |
| `lib/core/utils/soldout_utils.dart`       | Create                                                            |
| `lib/core/services/sold_out_service.dart` | Create                                                            |
| `lib/widgets/conflict_notice_modal.dart`  | Create                                                            |
| `lib/widgets/batch_bet_choice_modal.dart` | Create                                                            |
| `lib/controllers/lottery_controller.dart` | Modify — add cache, replace `isBetAvailable`, add two-pass submit |
| `lib/pages/app/bet_entry_page.dart`       | Modify — wire new check + modals                                  |

---

## Critical Business Rules (Do Not Break)

1. Rambol soldout is **group-level** — one sold-out perm disables Rambol for entire group.
2. Target soldout is **perm-level** — each exact combination has its own limit.
3. Rambol deducts from Target capacity — they share the same pool.
4. Two-pass submit validation — Pass 1 = all Targets, Pass 2 = all Rambols vs post-Target state.
5. Cart bets (`fromCart: true`) count toward exposure so server sees true remaining capacity.
6. `[1,1,2]` has 3 unique perms, not 6 — always use `countPermutations`.
7. Balance uses integer cents — avoid float rounding on deductions.
8. `drawTimeId` defaults to `drawId` when not explicitly set.
9. Per-schedule rows apply only on exact `dateStarted` day.
10. `soldOutCoversGroupKey` = sort-insensitive (Rambol). `exactOrderInSoldOut` = exact order (Target).

┌──────────────────────────────┬────────────────────────────────────────────────────────────┐  
 │ Endpoint │ Result │  
 ├──────────────────────────────┼────────────────────────────────────────────────────────────┤  
 │ GET /api/sold-out/list │ Returns active sold_outs, bet_numbers as JSON array │  
 │ │ pass-through, game_ids filter works │  
 ├──────────────────────────────┼────────────────────────────────────────────────────────────┤  
 │ GET │ 400 on missing params, empty {bets:[]} when no pending │
│ /api/bets/pending-exposure │ bets match │  
 ├──────────────────────────────┼────────────────────────────────────────────────────────────┤  
 │ POST │ New {results:[{index, is_available, available_amount, │
│ /api/bets/check-available │ limit, current_exposure}]} format │  
 └──────────────────────────────┴────────────────────────────────────────────────────────────┘
