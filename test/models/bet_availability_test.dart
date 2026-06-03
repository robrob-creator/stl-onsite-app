// Level 2 — pure conversion function, no network / no GetX
import 'package:flutter_test/flutter_test.dart';
import 'package:onstite/models/bet_availability.dart';
import 'package:onstite/models/permutation_availability.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

PermutationAvailability _perm({
  required String state,
  bool targetAllowed = true,
  double targetAvailable = 500,
  bool rambolAllowed = true,
  bool rambolDisabled = false,
  int permCount = 6,
  double minAmount = 6,
  bool anyPermSoldOut = false,
}) =>
    PermutationAvailability(
      success: true,
      state: state,
      anyPermSoldOut: anyPermSoldOut,
      rambolDisabled: rambolDisabled,
      showBetTypeSelection: true,
      target: PermTargetAvailability(
        allowed: targetAllowed,
        availableAmount: targetAvailable,
      ),
      rambol: PermRambolAvailability(
        allowed: rambolAllowed,
        permutationCount: permCount,
        minAmount: minAmount,
      ),
      permutations: const [],
      summary: const PermSummary(total: 6, soldOut: 0, available: 6),
    );

const _gameId = 'game-1';
const _drawTimeId = 'dt-1';
const _drawDate = '2026-05-23';
final _digits = ['1', '2', '3'];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('buildBetAvailabilityResult', () {
    // ── Returns null cases ────────────────────────────────────────────────────

    test('returns null when state is OPEN', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 100,
        rambolAmount: 0,
        perm: _perm(state: 'OPEN'),
      );
      expect(result, isNull);
    });

    test('returns null when PARTIALLY_SOLD but both types still allowed', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 100,
        rambolAmount: 60,
        perm: _perm(
          state: 'PARTIALLY_SOLD',
          targetAllowed: true,
          rambolAllowed: true,
        ),
      );
      expect(result, isNull);
    });

    test('returns null when no amounts requested', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 0,
        rambolAmount: 0,
        perm: _perm(state: 'SOLD_OUT', targetAllowed: false, rambolAllowed: false),
      );
      expect(result, isNull);
    });

    // ── Target blocked ────────────────────────────────────────────────────────

    test('target blocked → exceeds=true, betType=target', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 200,
        rambolAmount: 0,
        perm: _perm(state: 'SOLD_OUT', targetAllowed: false, targetAvailable: 0),
      );

      expect(result, isNotNull);
      expect(result!.exceeds, isTrue);
      expect(result.betType, BetType.target);
      expect(result.requestedAmount, 200.0);
      expect(result.availableAmount, 0.0);
      expect(result.state, AvailabilityState.soldOut);
      expect(result.target.allowed, isFalse);
      expect(result.target.availableAmount, 0.0);
    });

    test('target partially sold → state=partiallySold, availableAmount set', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 600,
        rambolAmount: 0,
        perm: _perm(
          state: 'PARTIALLY_SOLD',
          targetAllowed: false,
          targetAvailable: 300,
        ),
      );

      expect(result!.state, AvailabilityState.partiallySold);
      expect(result.availableAmount, 300.0);
      expect(result.requestedAmount, 600.0);
    });

    // ── Rambol blocked ────────────────────────────────────────────────────────

    test('rambol blocked via allowed=false → betType=rambol', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 0,
        rambolAmount: 60,
        perm: _perm(
          state: 'SOLD_OUT',
          rambolAllowed: false,
          anyPermSoldOut: true,
        ),
      );

      expect(result!.betType, BetType.rambol);
      expect(result.requestedAmount, 60.0);
      expect(result.availableAmount, isNull);
      expect(result.rambol.allowed, isFalse);
      expect(result.anyPermSoldOut, isTrue);
    });

    test('rambol blocked via rambolDisabled=true even when allowed=true', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 0,
        rambolAmount: 60,
        perm: _perm(
          state: 'PARTIALLY_SOLD',
          rambolAllowed: true,
          rambolDisabled: true,
        ),
      );

      expect(result!.betType, BetType.rambol);
      expect(result.rambol.allowed, isFalse);
    });

    // ── Both types requested ──────────────────────────────────────────────────

    test('both requested, only target blocked → betType=target (target takes priority)', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 200,
        rambolAmount: 60,
        perm: _perm(
          state: 'PARTIALLY_SOLD',
          targetAllowed: false,
          targetAvailable: 100,
          rambolAllowed: true,
        ),
      );

      expect(result!.betType, BetType.target);
      expect(result.requestedAmount, 200.0);
      expect(result.target.allowed, isFalse);
      expect(result.rambol.allowed, isTrue);
    });

    test('both requested, both blocked → betType=target (target takes priority)', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 200,
        rambolAmount: 60,
        perm: _perm(
          state: 'SOLD_OUT',
          targetAllowed: false,
          rambolAllowed: false,
          targetAvailable: 0,
        ),
      );

      expect(result!.betType, BetType.target);
      expect(result.target.allowed, isFalse);
      expect(result.rambol.allowed, isFalse);
      expect(result.exceeds, isTrue);
    });

    test('both requested, only rambol blocked → betType=rambol', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 200,
        rambolAmount: 60,
        perm: _perm(
          state: 'PARTIALLY_SOLD',
          targetAllowed: true,
          rambolAllowed: false,
          anyPermSoldOut: true,
        ),
      );

      expect(result!.betType, BetType.rambol);
      expect(result.requestedAmount, 60.0);
      expect(result.target.allowed, isTrue);
      expect(result.rambol.allowed, isFalse);
    });

    // ── Result fields ─────────────────────────────────────────────────────────

    test('result carries correct permutation metadata', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 0,
        rambolAmount: 60,
        perm: _perm(
          state: 'SOLD_OUT',
          rambolAllowed: false,
          permCount: 6,
          minAmount: 6,
          anyPermSoldOut: true,
        ),
      );

      expect(result!.permutationCount, 6);
      expect(result.minRambolAmount, 6.0);
      expect(result.anyPermSoldOut, isTrue);
      expect(result.gameId, _gameId);
      expect(result.number, '123');
      expect(result.drawId, _drawTimeId);
      expect(result.drawDate, _drawDate);
    });

    test('rambol availableAmount is always null (not applicable per-permutation)', () {
      final result = buildBetAvailabilityResult(
        gameId: _gameId,
        digits: _digits,
        drawTimeId: _drawTimeId,
        drawDate: _drawDate,
        targetAmount: 0,
        rambolAmount: 60,
        perm: _perm(state: 'SOLD_OUT', rambolAllowed: false),
      );

      expect(result!.rambol.availableAmount, isNull);
    });
  });
}
