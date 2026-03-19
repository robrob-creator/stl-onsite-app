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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Lottery type tabs
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
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
            const SizedBox(height: 20),
            // Date picker
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
            const SizedBox(height: 24),
            // Recent draws or loading state
            if (isLoadingResults)
              const Center(child: CircularProgressIndicator())
            else if (drawResults != null && drawResults!.drawTimes.isNotEmpty)
              ...drawResults!.drawTimes.map((drawTime) {
                final formattedTime = _formatDrawTime(drawTime.drawTime ?? '');
                final resultText = _parseResultString(
                  drawTime.latestResult?.result,
                );
                return _buildDrawCard(time: formattedTime, result: resultText);
              }).toList()
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
    );
  }

  Widget _buildDrawCard({required String time, required String result}) {
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
          // Result number
          Text(
            result,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Text(
              'Result Posted',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
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
    return '${months[date.month - 1]}, ${date.day.toString().padLeft(2, '0')} ${date.year}';
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
    if (result == null || result.isEmpty) return 'No Result';
    try {
      // Extract all numbers from the result string and join with dash
      final regex = RegExp(r'\d+');
      final numbers = regex
          .allMatches(result)
          .map((match) => match.group(0))
          .join('-');
      return numbers.isNotEmpty ? numbers : 'No Result';
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
