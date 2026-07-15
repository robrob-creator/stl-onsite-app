import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../core/design_system.dart';
import '../../core/services/draw_results_service.dart';
import '../../controllers/lottery_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedTab = 0; // 0 = 2D Lotto, 1 = 3D Lotto
  DateTime selectedDate = DateTime.now();
  late LotteryController lotteryController;
  DrawResultsResponse? drawResults;
  bool isLoadingResults = false;
  bool _hasError = false;
  Worker? _refreshWorker;

  static const _kChartStyleKey = 'dashboard_chart_style';
  final _storage = GetStorage();
  String _chartStyle = '1a'; // '1a' | '1b' | '1c'

  @override
  void initState() {
    super.initState();
    lotteryController = Get.find<LotteryController>();
    _chartStyle = _storage.read(_kChartStyleKey) ?? '1a';

    _refreshWorker = ever(lotteryController.drawRefreshTick, (_) {
      if (mounted) _fetchDrawResults();
    });

    _fetchDrawResults();
  }

  @override
  void dispose() {
    _refreshWorker?.dispose();
    super.dispose();
  }

  Future<void> _fetchDrawResults() async {
    if (!mounted) return;
    setState(() {
      isLoadingResults = true;
      _hasError = false;
    });

    try {
      final games = lotteryController.availableGames;
      if (games.isEmpty) {
        if (mounted) setState(() { isLoadingResults = false; });
        return;
      }

      final selectedGame = games[selectedTab];
      final drawDate =
          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

      final results = await DrawResultsService.getLatestResultsByGameAndDate(
        gameId: selectedGame.id,
        drawDate: drawDate,
      );

      if (!mounted) return;
      setState(() {
        drawResults = results;
        isLoadingResults = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingResults = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lottery type tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey[100]),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTab = 0;
                      });
                      _fetchDrawResults();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selectedTab == 0
                            ? Colors.white
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              image: const DecorationImage(
                                image: AssetImage(
                                  'assets/images/logos/lotto2d.png',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '2D Lotto',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTab = 1;
                      });
                      _fetchDrawResults();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: selectedTab == 1
                            ? Colors.white
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              image: const DecorationImage(
                                image: AssetImage(
                                  'assets/images/logos/lotto3d.png',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '3D Lotto',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: selectedTab == 1
                                  ? Colors.black87
                                  : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Date picker + chart switcher on same row
                Row(
                  children: [
                    _ChartStyleSwitcher(
                      selected: _chartStyle,
                      onChanged: (v) {
                        setState(() => _chartStyle = v);
                        _storage.write(_kChartStyleKey, v);
                      },
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(selectedDate),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Recent draws or loading state
                if (isLoadingResults)
                  const Center(child: CircularProgressIndicator())
                else if (_hasError)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load results',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _fetchDrawResults,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (drawResults != null &&
                    drawResults!.drawTimes.isNotEmpty)
                  ..._buildDrawCards()
                else
                  Center(
                    child: Text(
                      'No results available',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDrawCards() {
    if (drawResults == null || drawResults!.drawTimes.isEmpty) return [];
    final maxBet = drawResults!.drawTimes
        .map((d) => d.betSummary?.totalBet ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    return drawResults!.drawTimes.map((drawTime) {
      final formattedTime = _formatDrawTime(drawTime.drawTime ?? '');
      final resultText = _parseResultString(drawTime.latestResult?.result);
      return _buildDrawCard(
        time: formattedTime,
        result: resultText,
        winningAmnt: drawTime.latestResult?.winAmount?.toString(),
        totalBet: drawTime.betSummary?.totalBet ?? 0,
        totalWon: drawTime.betSummary?.totalWon ?? 0,
        maxTotalBet: maxBet,
        chartStyle: _chartStyle,
      );
    }).toList();
  }

  Widget _buildDrawCard({
    required String time,
    required String result,
    required String? winningAmnt,
    required int totalBet,
    required int totalWon,
    required int maxTotalBet,
    required String chartStyle,
  }) {
    final hasResult = result != '----';
    final hasActivity = totalBet > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EEFB), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header strip ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEF2FB), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                if (hasResult)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Result Posted',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gross Amount — HERO element
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GROSS SALES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasActivity
                                ? _formatAmount(totalBet.toString())
                                : '₱ —',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: hasActivity
                                  ? const Color(0xFF1E40AF)
                                  : const Color(0xFFCBD5E1),
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Result numbers — secondary, right-aligned
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'RESULT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          result,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: hasResult
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFCBD5E1),
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Gross vs Hits chart ────────────────────────────
                if (chartStyle == '1b')
                  _GrossHitsBar(totalBet: totalBet, totalWon: totalWon, maxTotalBet: maxTotalBet)
                else if (chartStyle == '1c')
                  _GrossHitsChips(totalBet: totalBet, totalWon: totalWon)
                else
                  _GrossHitsRing(totalBet: totalBet, totalWon: totalWon),

                // ── Prize payout ───────────────────────────────────
                if (winningAmnt != null && winningAmnt != '0') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFBBF7D0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 14,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Prize per Win',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF047857),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatAmount(winningAmnt),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(String? amount) {
    if (amount == null) return '--';
    final value = double.tryParse(amount);
    if (value == null) return '--';
    final intVal = value.toInt();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return '₱ ${buffer.toString()}';
  }

  String _formatDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    return '$weekday, $month.$day, ${date.year}';
  }

  String _formatDrawTime(String isoTime) {
    try {
      // Parse ISO 8601 format: "0000-01-01T10:30:00Z"
      final time = DateTime.parse(isoTime);
      final hour = time.hour;
      final minute = time.minute;

      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return isoTime; // Return original if parsing fails
    }
  }

  String _parseResultString(String? result) {
    if (result == null || result.isEmpty) return '----';
    try {
      // Extract all numbers from the result string and join with dash
      final regex = RegExp(r'\d+');
      final numbers = regex
          .allMatches(result)
          .map((match) => match.group(0))
          .join('-');
      return numbers.isNotEmpty ? numbers : '----';
    } catch (e) {
      return result;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _fetchDrawResults();
    }
  }
}

class _GrossHitsRing extends StatelessWidget {
  final int totalBet;
  final int totalWon;

  const _GrossHitsRing({required this.totalBet, required this.totalWon});

  String _fmt(int v) {
    if (v == 0) return '₱ 0';
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '₱ ${buf.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final payoutRatio = totalBet > 0 ? totalWon / totalBet : 0.0;
    final netAmount = totalBet - totalWon;
    final isProfit = netAmount >= 0;
    final ringRatio = payoutRatio.clamp(0.0, 1.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Ring chart
        SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(84, 84),
                painter: _RingPainter(ratio: ringRatio, isOverPayout: payoutRatio > 1),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmt(totalBet),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isProfit ? const Color(0xFF1D3A8A) : const Color(0xFF9A2C24),
                      height: 1.2,
                    ),
                  ),
                  const Text(
                    'Sales',
                    style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: Color(0xFF9AA3B2)),
                  ),
                  Container(height: 1, width: 20, color: Color(0xFFE2E8F0), margin: EdgeInsets.symmetric(vertical: 2)),
                  Text(
                    _fmt(totalWon),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9A2C24),
                      height: 1.2,
                    ),
                  ),
                  const Text(
                    'Hits',
                    style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: Color(0xFF9AA3B2)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Stats column
        Expanded(
          child: Column(
            children: [
              // Hits row
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Hits',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB4453F)),
                  ),
                  const Spacer(),
                  Text(
                    _fmt(totalWon),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF9A2C24)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFEEF1F6)),
              const SizedBox(height: 8),
              // Net Result row
              Row(
                children: [
                  Text(
                    'Net Result',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isProfit ? const Color(0xFF1D3A8A) : const Color(0xFFB91C1C),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isProfit ? '+${_fmt(netAmount)}' : '-${_fmt(netAmount.abs())}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isProfit ? const Color(0xFF1D3A8A) : const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double ratio;
  final bool isOverPayout;

  _RingPainter({required this.ratio, required this.isOverPayout});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;
    const strokeWidth = 10.0;

    // Background track
    final trackPaint = Paint()
      ..color = const Color(0xFFEEF1F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Arc fill (starts from top = -π/2)
    if (ratio > 0) {
      final arcPaint = Paint()
        ..color = isOverPayout ? const Color(0xFFDC2626) : const Color(0xFF2563EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * ratio;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.ratio != ratio || old.isOverPayout != isOverPayout;
}

// ── 1b: Single Hits bar relative to Gross + Net Result callout ──────────────
class _GrossHitsBar extends StatelessWidget {
  final int totalBet;
  final int totalWon;
  final int maxTotalBet;
  const _GrossHitsBar({required this.totalBet, required this.totalWon, required this.maxTotalBet});

  String _fmt(int v) {
    if (v == 0) return '₱ 0';
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '₱ ${buf.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final grossFactor = maxTotalBet > 0 ? (totalBet / maxTotalBet).clamp(0.0, 1.0) : 0.0;
    final hitsAbsoluteFactor = maxTotalBet > 0 ? (totalWon / maxTotalBet).clamp(0.0, 1.0) : 0.0;
    final netAmount = totalBet - totalWon;
    final isProfit = netAmount >= 0;
    final isOverPayout = totalWon > totalBet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Gross bar (proportional to max across all draw times)
            _Bar(
              value: _fmt(totalBet),
              heightFactor: grossFactor,
              color: const Color(0xFF2563EB),
              gradientTop: const Color(0xFF3B7BF0),
              label: 'Gross',
              labelColor: const Color(0xFF3B5DAA),
              valueColor: const Color(0xFF1D3A8A),
            ),
            const SizedBox(width: 18),
            // Hits bar (proportional to max gross)
            _Bar(
              value: _fmt(totalWon),
              heightFactor: hitsAbsoluteFactor,
              color: isOverPayout ? const Color(0xFFDC2626) : const Color(0xFF10B981),
              gradientTop: isOverPayout ? const Color(0xFFEC5A50) : const Color(0xFF34D399),
              label: 'Hits',
              labelColor: isOverPayout ? const Color(0xFFB4453F) : const Color(0xFF047857),
              valueColor: isOverPayout ? const Color(0xFF9A2C24) : const Color(0xFF065F46),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isProfit ? const Color(0xFFEFF4FE) : const Color(0xFFFDEBEC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 15,
                color: isProfit ? const Color(0xFF2563EB) : const Color(0xFFB91C1C),
              ),
              const SizedBox(width: 6),
              Text(
                'Net Result',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isProfit ? const Color(0xFF1D3A8A) : const Color(0xFFB91C1C),
                ),
              ),
              const Spacer(),
              Text(
                isProfit ? '+${_fmt(netAmount)}' : '-${_fmt(netAmount.abs())}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isProfit ? const Color(0xFF1D3A8A) : const Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final String value;
  final double heightFactor;
  final Color color;
  final Color gradientTop;
  final String label;
  final Color labelColor;
  final Color valueColor;

  const _Bar({
    required this.value,
    required this.heightFactor,
    required this.color,
    required this.gradientTop,
    required this.label,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    const maxH = 72.0;
    final barH = (maxH * heightFactor).clamp(4.0, maxH);

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: valueColor),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: barH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [gradientTop, color],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(4)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: labelColor)),
        ],
      ),
    );
  }
}

// ── 1c: Net Result hero + Hits chip only (Gross already shown above) ─────────
class _GrossHitsChips extends StatelessWidget {
  final int totalBet;
  final int totalWon;
  const _GrossHitsChips({required this.totalBet, required this.totalWon});

  String _fmt(int v) {
    if (v == 0) return '₱ 0';
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '₱ ${buf.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final netAmount = totalBet - totalWon;
    final isProfit = netAmount >= 0;

    return Row(
      children: [
        // Net Result
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NET RESULT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isProfit ? '+${_fmt(netAmount)}' : '-${_fmt(netAmount.abs())}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isProfit ? const Color(0xFF1D3A8A) : const Color(0xFFB91C1C),
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Hits chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFDEEEE),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              const Text('Hits', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB4453F))),
              const SizedBox(width: 6),
              Text(
                _fmt(totalWon),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF9A2C24)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Chart style switcher ─────────────────────────────────────────────────────
class _ChartStyleSwitcher extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _ChartStyleSwitcher({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [('1a', 'Ring'), ('1b', 'Bars'), ('1c', 'Net')].map((opt) {
          final id = opt.$1;
          final label = opt.$2;
          final isSelected = selected == id;
          return GestureDetector(
            onTap: () => onChanged(id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

