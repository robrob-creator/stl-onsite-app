import 'dart:math' show min;

import 'permutation_availability.dart';

enum BetType { target, rambol }

enum AvailabilityState { open, partiallySold, soldOut }

class NormalizedBet {
  final String gameId;
  final List<String> digits;
  final String number;
  final String groupKey;
  final BetType betType;
  final String drawId;
  final String drawDate;
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

/// Converts a [PermutationAvailability] endpoint response into a
/// [BetAvailabilityResult] for conflict modal display.
/// Returns null when no conflict (state is OPEN or all requested types are allowed).
BetAvailabilityResult? buildBetAvailabilityResult({
  required String gameId,
  required List<String> digits,
  required String drawTimeId,
  required String drawDate,
  required double targetAmount,
  required double rambolAmount,
  required PermutationAvailability perm,
}) {
  final targetAllowed = perm.target.allowed;
  final rambolAllowed = perm.rambol.allowed && !perm.rambolDisabled;

  // Check if requested amount exceeds available even when state is OPEN.
  final targetAvail = perm.target.availableAmount;
  final targetAmountExceeds = targetAmount > 0 &&
      targetAvail > 0 &&
      targetAmount > targetAvail;

  // N = available (non-sold-out) perms per swerte888 rules
  final N = perm.summary.available > 0
      ? perm.summary.available
      : perm.rambol.permutationCount;
  final rambolAmountExceeds = rambolAmount > 0 &&
      N > 0 &&
      perm.permutations.isNotEmpty &&
      perm.permutations.any((p) {
        final share = rambolAmount / N;
        return !p.isSoldOut && p.remaining > 0 && share > p.remaining;
      });

  // Compute max valid rambol amount for conflict modal "update to ₱X"
  double? rambolAvailAmt;
  if (rambolAmount > 0 && N > 0 && perm.permutations.isNotEmpty) {
    final availPerms = perm.permutations.where((p) => !p.isSoldOut && p.remaining > 0);
    if (availPerms.isNotEmpty) {
      final minRem = availPerms.map((p) => p.remaining).reduce(min);
      final candidate = (minRem.floor() * N).toDouble();
      if (candidate >= N) rambolAvailAmt = candidate;
    }
  }

  final targetExceeds = targetAmount > 0 && (!targetAllowed || targetAmountExceeds);
  final rambolExceeds = rambolAmount > 0 && (!rambolAllowed || rambolAmountExceeds);

  if (perm.state == 'OPEN' && !targetAmountExceeds && !rambolAmountExceeds) return null;

  if (!targetExceeds && !rambolExceeds) return null;

  final betType = targetExceeds ? BetType.target : BetType.rambol;
  final requestedAmt = targetExceeds ? targetAmount : rambolAmount;
  final availAmt = targetExceeds ? perm.target.availableAmount : rambolAvailAmt;

  final state = perm.state == 'SOLD_OUT'
      ? AvailabilityState.soldOut
      : AvailabilityState.partiallySold;

  return BetAvailabilityResult(
    gameId: gameId,
    number: digits.join(),
    groupKey: digits.join(),
    betType: betType,
    drawId: drawTimeId,
    drawDate: drawDate,
    currentExposure: 0,
    requestedAmount: requestedAmt,
    availableAmount: availAmt,
    limit: null,
    exceeds: true,
    state: state,
    permutationCount: perm.rambol.permutationCount,
    minRambolAmount: perm.rambol.minAmount,
    anyPermSoldOut: perm.anyPermSoldOut,
    target: BetTypeAvailability(
      allowed: targetAllowed,
      availableAmount: perm.target.availableAmount,
      reason: targetAllowed ? null : 'Target is not available',
    ),
    rambol: BetTypeAvailability(
      allowed: rambolAllowed,
      availableAmount: rambolAvailAmt,
      reason: rambolAllowed ? null : 'Rambol is not available',
    ),
  );
}
