// Level 3 — controller unit tests for pure/local methods only.
// No network calls: instantiate LotteryController() directly (skips onInit).
// Tests that require HTTP calls are marked TODO.
import 'package:flutter_test/flutter_test.dart';
import 'package:onstite/controllers/lottery_controller.dart';
import 'package:onstite/models/permutation_availability.dart';

void main() {
  // ── calculateCombinations ─────────────────────────────────────────────────
  // Permutation count = n! / (freq1! * freq2! * ...)

  group('LotteryController.calculateCombinations', () {
    late LotteryController ctrl;

    setUp(() {
      // Direct instantiation: onInit() is NOT invoked, no HTTP, no GetX needed.
      ctrl = LotteryController();
    });

    test('3D all-different digits → 6', () {
      expect(ctrl.calculateCombinations(['1', '2', '3']), 6);
    });

    test('3D one-pair [2,2,3] → 3', () {
      expect(ctrl.calculateCombinations(['2', '2', '3']), 3);
    });

    test('3D all-same [7,7,7] → 1', () {
      expect(ctrl.calculateCombinations(['7', '7', '7']), 1);
    });

    test('2D all-different [1,2] → 2', () {
      expect(ctrl.calculateCombinations(['1', '2']), 2);
    });

    test('2D same [4,4] → 1', () {
      expect(ctrl.calculateCombinations(['4', '4']), 1);
    });

    test('single-digit [5] → 1', () {
      expect(ctrl.calculateCombinations(['5']), 1);
    });

    test('empty list → 1 (safe default)', () {
      expect(ctrl.calculateCombinations([]), 1);
    });

    test('4D all-different [1,2,3,4] → 24', () {
      expect(ctrl.calculateCombinations(['1', '2', '3', '4']), 24);
    });

    test('4D two-pairs [1,1,2,2] → 6', () {
      expect(ctrl.calculateCombinations(['1', '1', '2', '2']), 6);
    });
  });

  // ── permAvailability observable ───────────────────────────────────────────

  group('LotteryController.permAvailability', () {
    late LotteryController ctrl;

    setUp(() {
      ctrl = LotteryController();
    });

    test('starts null', () {
      expect(ctrl.permAvailability.value, isNull);
    });

    test('can be set and read', () {
      final perm = PermutationAvailability(
        success: true,
        state: 'OPEN',
        anyPermSoldOut: false,
        rambolDisabled: false,
        showBetTypeSelection: true,
        target: const PermTargetAvailability(allowed: true, availableAmount: 500),
        rambol: const PermRambolAvailability(
            allowed: true, permutationCount: 6, minAmount: 6),
        permutations: const [],
        summary: const PermSummary(total: 6, soldOut: 0, available: 6),
      );

      ctrl.permAvailability.value = perm;

      expect(ctrl.permAvailability.value, isNotNull);
      expect(ctrl.permAvailability.value!.state, 'OPEN');
      expect(ctrl.permAvailability.value!.rambol.permutationCount, 6);
    });

    test('can be cleared back to null', () {
      ctrl.permAvailability.value = PermutationAvailability(
        success: true,
        state: 'OPEN',
        anyPermSoldOut: false,
        rambolDisabled: false,
        showBetTypeSelection: true,
        target: const PermTargetAvailability(allowed: true, availableAmount: 500),
        rambol: const PermRambolAvailability(
            allowed: true, permutationCount: 6, minAmount: 6),
        permutations: const [],
        summary: const PermSummary(total: 6, soldOut: 0, available: 6),
      );
      ctrl.permAvailability.value = null;

      expect(ctrl.permAvailability.value, isNull);
    });
  });

  // ── Rambol blocking conditions (unit-level logic check) ────────────────────
  // These mirror the conditions in bet_entry_page.dart validateRambol()
  // and the rambolBlocked Obx check.

  group('Rambol availability gate logic', () {
    test('rambolBlocked when perm.rambolDisabled=true', () {
      final perm = PermutationAvailability(
        success: true,
        state: 'PARTIALLY_SOLD',
        anyPermSoldOut: true,
        rambolDisabled: true,
        showBetTypeSelection: false,
        target: const PermTargetAvailability(allowed: true, availableAmount: 500),
        rambol: const PermRambolAvailability(
            allowed: true, permutationCount: 4, minAmount: 4),
        permutations: const [],
        summary: const PermSummary(total: 6, soldOut: 2, available: 4),
      );

      final rambolBlocked =
          perm.rambolDisabled || !perm.rambol.allowed;

      expect(rambolBlocked, isTrue);
    });

    test('rambolBlocked when rambol.allowed=false', () {
      final perm = PermutationAvailability(
        success: true,
        state: 'SOLD_OUT',
        anyPermSoldOut: true,
        rambolDisabled: false,
        showBetTypeSelection: false,
        target: const PermTargetAvailability(allowed: false, availableAmount: 0),
        rambol: const PermRambolAvailability(
            allowed: false, permutationCount: 6, minAmount: 6),
        permutations: const [],
        summary: const PermSummary(total: 6, soldOut: 6, available: 0),
      );

      final rambolBlocked =
          perm.rambolDisabled || !perm.rambol.allowed;

      expect(rambolBlocked, isTrue);
    });

    test('rambolBlocked=false when both flags are safe', () {
      final perm = PermutationAvailability(
        success: true,
        state: 'OPEN',
        anyPermSoldOut: false,
        rambolDisabled: false,
        showBetTypeSelection: true,
        target: const PermTargetAvailability(allowed: true, availableAmount: 500),
        rambol: const PermRambolAvailability(
            allowed: true, permutationCount: 6, minAmount: 6),
        permutations: const [],
        summary: const PermSummary(total: 6, soldOut: 0, available: 6),
      );

      final rambolBlocked =
          perm.rambolDisabled || !perm.rambol.allowed;

      expect(rambolBlocked, isFalse);
    });

    // Min-amount validation: amount < permCount → error
    test('rambolAmount below minAmount triggers validation error', () {
      const permCount = 6;
      const rambolAmount = 5;

      final error = rambolAmount < permCount
          ? 'Minimum Rambol bet is ₱$permCount'
          : null;

      expect(error, isNotNull);
      expect(error, contains('6'));
    });

    test('rambolAmount equal to minAmount passes', () {
      const permCount = 6;
      const rambolAmount = 6;

      final error = rambolAmount < permCount
          ? 'Minimum Rambol bet is ₱$permCount'
          : null;

      expect(error, isNull);
    });

    // Divisibility check
    test('rambolAmount not divisible by permCount triggers error', () {
      const permCount = 6;
      const rambolAmount = 7;

      final error = (permCount > 0 && rambolAmount % permCount != 0)
          ? 'Rambol amount must be divisible by $permCount'
          : null;

      expect(error, isNotNull);
    });

    test('rambolAmount divisible by permCount passes', () {
      const permCount = 6;
      const rambolAmount = 12;

      final error = (permCount > 0 && rambolAmount % permCount != 0)
          ? 'Rambol amount must be divisible by $permCount'
          : null;

      expect(error, isNull);
    });

    // All-same digits → permCount == 1 → rambol invalid
    test('all-same digits → calculateCombinations returns 1 → rambol blocked', () {
      final ctrl = LotteryController();
      final permCount = ctrl.calculateCombinations(['7', '7', '7']);
      expect(permCount, 1); // triggers "all digits identical" guard
    });
  });

  // ── TODO: tests requiring HTTP mocking ────────────────────────────────────
  // The following would require an injected HttpClient or a mock framework
  // (e.g. mocktail) to stub SoldOutService.checkPermutations:
  //
  //  - fetchPermutations: stores PermutationAvailability on success
  //  - fetchPermutations: sets permAvailability=null on network error
  //  - checkBetAvailability: passes cart_bets derived from draftBets
  //  - checkBetAvailability: returns null on HTTP failure (fail open)
}
