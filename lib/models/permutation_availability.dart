class PermTargetAvailability {
  final bool allowed;
  final double availableAmount;

  const PermTargetAvailability({
    required this.allowed,
    required this.availableAmount,
  });

  factory PermTargetAvailability.fromJson(Map<String, dynamic> j) =>
      PermTargetAvailability(
        allowed: j['allowed'] as bool? ?? true,
        availableAmount: (j['availableAmount'] as num?)?.toDouble() ?? 0,
      );
}

class PermRambolAvailability {
  final bool allowed;
  final int permutationCount;
  final double minAmount;

  const PermRambolAvailability({
    required this.allowed,
    required this.permutationCount,
    required this.minAmount,
  });

  factory PermRambolAvailability.fromJson(Map<String, dynamic> j) =>
      PermRambolAvailability(
        allowed: j['allowed'] as bool? ?? true,
        permutationCount: j['permutationCount'] as int? ?? 1,
        minAmount: (j['minAmount'] as num?)?.toDouble() ?? 1,
      );
}

class PermutationDetail {
  final String value;
  final double exposure;
  final double remaining;
  final bool isSoldOut;

  const PermutationDetail({
    required this.value,
    required this.exposure,
    required this.remaining,
    required this.isSoldOut,
  });

  factory PermutationDetail.fromJson(Map<String, dynamic> j) =>
      PermutationDetail(
        value: j['value'] as String? ?? '',
        exposure: (j['exposure'] as num?)?.toDouble() ?? 0,
        remaining: (j['remaining'] as num?)?.toDouble() ?? 0,
        isSoldOut: j['isSoldOut'] as bool? ?? false,
      );
}

class PermSummary {
  final int total;
  final int soldOut;
  final int available;

  const PermSummary({
    required this.total,
    required this.soldOut,
    required this.available,
  });

  factory PermSummary.fromJson(Map<String, dynamic> j) => PermSummary(
        total: j['total'] as int? ?? 0,
        soldOut: j['sold_out'] as int? ?? 0,
        available: j['available'] as int? ?? 0,
      );
}

class PermutationAvailability {
  final bool success;
  final String state; // 'OPEN' | 'PARTIALLY_SOLD' | 'SOLD_OUT'
  final bool anyPermSoldOut;
  final bool rambolDisabled;
  final bool showBetTypeSelection;
  final PermTargetAvailability target;
  final PermRambolAvailability rambol;
  final List<PermutationDetail> permutations;
  final PermSummary summary;

  const PermutationAvailability({
    required this.success,
    required this.state,
    required this.anyPermSoldOut,
    required this.rambolDisabled,
    required this.showBetTypeSelection,
    required this.target,
    required this.rambol,
    required this.permutations,
    required this.summary,
  });

  factory PermutationAvailability.fromJson(Map<String, dynamic> j) =>
      PermutationAvailability(
        success: j['success'] as bool? ?? false,
        state: j['state'] as String? ?? 'OPEN',
        anyPermSoldOut: j['anyPermSoldOut'] as bool? ?? false,
        rambolDisabled: j['rambolDisabled'] as bool? ?? false,
        showBetTypeSelection: j['showBetTypeSelection'] as bool? ?? true,
        target: PermTargetAvailability.fromJson(
            j['target'] as Map<String, dynamic>? ?? {}),
        rambol: PermRambolAvailability.fromJson(
            j['rambol'] as Map<String, dynamic>? ?? {}),
        permutations: (j['permutations'] as List? ?? [])
            .map((e) =>
                PermutationDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: PermSummary.fromJson(
            j['summary'] as Map<String, dynamic>? ?? {}),
      );
}
