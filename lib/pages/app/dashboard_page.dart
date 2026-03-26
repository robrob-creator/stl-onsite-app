import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  @override
  void initState() {
    super.initState();
    lotteryController = Get.find<LotteryController>();
    _fetchDrawResults();
  }

  Future<void> _fetchDrawResults() async {
    setState(() {
      isLoadingResults = true;
    });

    try {
      // Get the game ID based on selected tab
      final games = lotteryController.availableGames;
      if (games.isEmpty) {
        setState(() {
          isLoadingResults = false;
        });
        return;
      }

      final selectedGame = games[selectedTab];
      final drawDate =
          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

      final results = await DrawResultsService.getLatestResultsByGameAndDate(
        gameId: selectedGame.id,
        drawDate: drawDate,
      );

      setState(() {
        drawResults = results;
        isLoadingResults = false;
      });
    } catch (e) {
      setState(() {
        isLoadingResults = false;
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
                // Date picker
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
    final allAmounts = drawResults!.drawTimes
        .map((dt) => dt.latestResult?.winAmount ?? 0)
        .toList();
    return drawResults!.drawTimes.asMap().entries.map((entry) {
      final i = entry.key;
      final drawTime = entry.value;
      final formattedTime = _formatDrawTime(drawTime.drawTime ?? '');
      final resultText = _parseResultString(drawTime.latestResult?.result);
      return _buildDrawCard(
        time: formattedTime,
        result: resultText,
        winningAmnt: drawTime.latestResult?.winAmount?.toString(),
        chartData: allAmounts,
        highlightIndex: i,
        totalBet: drawTime.betSummary?.totalBet ?? 0,
        totalWon: drawTime.betSummary?.totalWon ?? 0,
      );
    }).toList();
  }

  Widget _buildDrawCard({
    required String time,
    required String result,
    required String? winningAmnt,
    required List<int> chartData,
    required int highlightIndex,
    required int totalBet,
    required int totalWon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[100]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Result number + mini bar chart
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                result,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: result == "----" ? Colors.grey : Colors.black,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              _MiniLineChart(
                values: chartData,
                highlightIndex: highlightIndex,
                isGreen: totalBet > totalWon,
                isFlat: totalBet == totalWon,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status badge
          Text(
            _formatAmount(winningAmnt),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
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

class _MiniLineChart extends StatelessWidget {
  final List<int> values;
  final int highlightIndex;
  final bool isGreen;
  final bool isFlat;

  const _MiniLineChart({
    required this.values,
    required this.highlightIndex,
    required this.isGreen,
    this.isFlat = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFlat
        ? const Color(0xFFB0B0B0)
        : isGreen
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);

    return SizedBox(
      width: 100,
      height: 60,
      child: CustomPaint(
        painter: _LineChartPainter(values: values, color: color),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> values;
  final Color color;

  _LineChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final maxVal = values.reduce((a, b) => a > b ? a : b).toDouble();
    final minVal = values.reduce((a, b) => a < b ? a : b).toDouble();
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    // Map values to canvas points
    final points = List.generate(values.length, (i) {
      final x = i / (values.length - 1) * size.width;
      final y =
          size.height -
          ((values[i] - minVal) / range) * (size.height * 0.7) -
          size.height * 0.1;
      return Offset(x, y);
    });

    // Build smooth bezier path
    final linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset(
        points[i].dx + (points[i + 1].dx - points[i].dx) / 2,
        points[i].dy,
      );
      final cp2 = Offset(
        points[i].dx + (points[i + 1].dx - points[i].dx) / 2,
        points[i + 1].dy,
      );
      linePath.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }

    // Filled area path
    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = color.withOpacity(0.12)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.values != values || old.color != color;
}
