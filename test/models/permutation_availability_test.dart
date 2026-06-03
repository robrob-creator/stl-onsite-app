// Level 1 — pure model parsing, no dependencies
import 'package:flutter_test/flutter_test.dart';
import 'package:onstite/models/permutation_availability.dart';

void main() {
  // ── PermutationAvailability.fromJson ──────────────────────────────────────

  group('PermutationAvailability.fromJson', () {
    test('parses full OPEN response', () {
      final json = {
        'success': true,
        'state': 'OPEN',
        'anyPermSoldOut': false,
        'rambolDisabled': false,
        'showBetTypeSelection': true,
        'target': {'allowed': true, 'availableAmount': 500},
        'rambol': {'allowed': true, 'permutationCount': 6, 'minAmount': 6},
        'permutations': [
          {'value': '1|2|3', 'exposure': 120.0, 'remaining': 380.0, 'isSoldOut': false},
        ],
        'summary': {'total': 6, 'sold_out': 0, 'available': 6},
      };

      final result = PermutationAvailability.fromJson(json);

      expect(result.success, isTrue);
      expect(result.state, 'OPEN');
      expect(result.anyPermSoldOut, isFalse);
      expect(result.rambolDisabled, isFalse);
      expect(result.showBetTypeSelection, isTrue);

      expect(result.target.allowed, isTrue);
      expect(result.target.availableAmount, 500.0);

      expect(result.rambol.allowed, isTrue);
      expect(result.rambol.permutationCount, 6);
      expect(result.rambol.minAmount, 6.0);

      expect(result.permutations, hasLength(1));
      expect(result.permutations[0].value, '1|2|3');
      expect(result.permutations[0].exposure, 120.0);
      expect(result.permutations[0].remaining, 380.0);
      expect(result.permutations[0].isSoldOut, isFalse);

      expect(result.summary.total, 6);
      expect(result.summary.soldOut, 0);
      expect(result.summary.available, 6);
    });

    test('parses SOLD_OUT state with anyPermSoldOut true', () {
      final json = {
        'success': true,
        'state': 'SOLD_OUT',
        'anyPermSoldOut': true,
        'rambolDisabled': true,
        'showBetTypeSelection': false,
        'target': {'allowed': false, 'availableAmount': 0},
        'rambol': {'allowed': false, 'permutationCount': 6, 'minAmount': 6},
        'permutations': [],
        'summary': {'total': 6, 'sold_out': 6, 'available': 0},
      };

      final result = PermutationAvailability.fromJson(json);

      expect(result.state, 'SOLD_OUT');
      expect(result.anyPermSoldOut, isTrue);
      expect(result.rambolDisabled, isTrue);
      expect(result.showBetTypeSelection, isFalse);
      expect(result.target.allowed, isFalse);
      expect(result.target.availableAmount, 0.0);
      expect(result.rambol.allowed, isFalse);
      expect(result.summary.soldOut, 6);
      expect(result.summary.available, 0);
    });

    test('parses PARTIALLY_SOLD — target blocked, rambol still open', () {
      final json = {
        'success': true,
        'state': 'PARTIALLY_SOLD',
        'anyPermSoldOut': true,
        'rambolDisabled': false,
        'showBetTypeSelection': true,
        'target': {'allowed': false, 'availableAmount': 0},
        'rambol': {'allowed': true, 'permutationCount': 4, 'minAmount': 4},
        'permutations': [
          {'value': '1|2|3', 'exposure': 500.0, 'remaining': 0.0, 'isSoldOut': true},
          {'value': '1|3|2', 'exposure': 200.0, 'remaining': 300.0, 'isSoldOut': false},
        ],
        'summary': {'total': 6, 'sold_out': 2, 'available': 4},
      };

      final result = PermutationAvailability.fromJson(json);

      expect(result.state, 'PARTIALLY_SOLD');
      expect(result.target.allowed, isFalse);
      expect(result.rambol.allowed, isTrue);
      expect(result.rambol.permutationCount, 4);
      expect(result.rambol.minAmount, 4.0);
      expect(result.permutations[0].isSoldOut, isTrue);
      expect(result.permutations[1].isSoldOut, isFalse);
      expect(result.summary.soldOut, 2);
      expect(result.summary.available, 4);
    });

    test('applies safe defaults for missing fields', () {
      final result = PermutationAvailability.fromJson({});

      expect(result.success, isFalse);
      expect(result.state, 'OPEN');
      expect(result.anyPermSoldOut, isFalse);
      expect(result.rambolDisabled, isFalse);
      expect(result.showBetTypeSelection, isTrue);
      expect(result.target.allowed, isTrue);
      expect(result.target.availableAmount, 0.0);
      expect(result.rambol.allowed, isTrue);
      expect(result.rambol.permutationCount, 1);
      expect(result.rambol.minAmount, 1.0);
      expect(result.permutations, isEmpty);
      expect(result.summary.total, 0);
    });

    test('permutations list parsed with multiple entries', () {
      final json = {
        'success': true,
        'state': 'OPEN',
        'anyPermSoldOut': false,
        'rambolDisabled': false,
        'showBetTypeSelection': true,
        'target': {'allowed': true, 'availableAmount': 500},
        'rambol': {'allowed': true, 'permutationCount': 6, 'minAmount': 6},
        'permutations': [
          {'value': '1|2|3', 'exposure': 0.0, 'remaining': 500.0, 'isSoldOut': false},
          {'value': '1|3|2', 'exposure': 0.0, 'remaining': 500.0, 'isSoldOut': false},
          {'value': '2|1|3', 'exposure': 500.0, 'remaining': 0.0, 'isSoldOut': true},
        ],
        'summary': {'total': 6, 'sold_out': 1, 'available': 5},
      };

      final result = PermutationAvailability.fromJson(json);

      expect(result.permutations, hasLength(3));
      expect(result.permutations.where((p) => p.isSoldOut).length, 1);
      expect(result.permutations.where((p) => !p.isSoldOut).length, 2);
    });
  });
}
